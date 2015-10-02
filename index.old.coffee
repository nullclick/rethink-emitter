
EventEmitter = require 'events'

util = require 'util'

async = require 'async'
debug = require 'debug'
r     = require 'rethinkdb'


___ = (k)  -> console.log util.inspect k, { colors: yes, depth: null }
___ = debug 'rethink-emitter'

###
arguments callback shifter helper function

This is meant to be passed the arguments object from within a function
where there are optional (or just an unknown number of) arguments.  It
normally isn't used directly, but by action queuers where the methods
that get queued have all sorts of function signatures.

@darkle core v1.0.1

@example
	test = (error, something, callback) ->
		[ callback, error, rest... ] = $ arguments
		___ { callback, error, rest }
	test 1, 2, 3, 4 # { callback: 1, error, 2, rest: [3, 4] }
###
$ = (k) -> 
	args = Array::slice.call(k)
	args[..-1] = args.pop()
	return args


queued_method = (object, name, method) ->

class QueuerObject

	constructor: ->
		super

	add_method: (name, document, method) ->
		# export documentation
		@[name] = -> @__queue.push { method: '__' + name, args: arguments }

class RethinkEmitter extends EventEmitter
	constructor: (options, onceready) ->
		super

		options       = options       || {}
		options.table = options.table || 'events'

		
		# bind callback to 'ready' if one is provided
		@once 'ready', onceready if onceready?

		# keep all calls in a queue and process each 
		@__queue = async.queue (item, callback) =>
			args = Array::slice.call item.args
			@[item.method].apply @, args.concat callback
		@__queue.pause()
		@once 'ready', @__queue.resume


		# connect to database, create table, and get a uuid tag
		async.waterfall [
			(callback) ->
				r.connect options, (error, connection) ->
					return callback error if error?
					callback null, connection

			(connection, callback) =>
				r.tableCreate options.table
					.run connection, (error) ->
						# suppress error (ie. if table already exists)
						callback null, connection

			(connection, callback) ->
				r.uuid().run connection, (error, uuid) ->
					return callback error if error?
					callback null, connection, uuid

			(connection, uuid, callback) ->
				callback null, connection, uuid, r.table(options.table)

		], (error, connection, uuid_tag, table) =>
			throw error if error?

			@connection = connection
			@event_uuid = uuid_tag
			@__table    = table

			@emit 'ready', uuid_tag

		
RethinkEmitter::test_a = (obj) ->
	@__queue.push { method: '__test_a', args: arguments }
RethinkEmitter::__test_a = (obj, callback) ->
	[ callback, obj ] = $ arguments
	@__table.insert(obj).run @connection, (error, results) ->
		___ { obj: obj, results: results }
		callback error, results

RethinkEmitter::test_b = (obj) ->
	@__queue.push { method: '__test_b', args: arguments }
RethinkEmitter::__test_b = (obj, callback) ->
	[ callback, obj ] = $ arguments
	@__table.insert(obj).run @connection, (error, results) ->
		___ { obj: obj, results: results }
		callback error, results

RethinkEmitter::emit = (event, args...) ->
	___ { method: 'emit', event: event, args: args }
	@__queue.push { method: '__emit', args: arguments }
	super event, args...
RethinkEmitter::__emit = (event, args..., callback) ->
	___ { method: '__emit', event: event, args: args }
	callback null


module.exports = RethinkEmitter
