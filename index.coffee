
os = require 'os'

Queuer = require './darkle/queuer'

async = require 'async'
debug = require('debug') 'rethink-emitter'
r     = require 'rethinkdb'



# internal emitting for process control
# I'm not sure exactly what the issue is, but using the @emit where this is used
# causes the rethinkdb (and/or async) to totally lose it's shit.  I'm sure it's
# something stupid i'm doing with the Queuer functionality that's causing async
# to trigger a listener that falls out of scope.  It looks like somewhere I am
# leaving rethinkdb a function expression that doesn't exist?  Tracing through
# this is proving to be a total pain in the ass, and this cheap hack works well
# enough for now since it's not really necessary to be writing and remote emitting
# process control events.  I could also just replace the emits with direct code.
local_emit = (obj, event, args...) ->
	debug { direct_emit: event, args: args }
	Queuer::emit.call obj, event, args...


class RethinkEmitter extends Queuer

	constructor: (options, onceReady) ->
		super no # do not start queue automatically

		@options = options = options || {}
		@options.table     = options.table || 'events'

		async.waterfall [
			# connect to rethinkdb database server
			(callback) =>
				if options.connection
					debug { connecting: 'skip', connection: connection }
					callback null, options.connection
				else
					debug { connecting: options }
					r.connect options, (error, connection) ->
						debug { connecting: 'complete', error: error, connection: connection }
						options.connection = connection
						callback error, connection

			# create the events table if necessary
			(connection, callback) ->
				debug { creating_table: options.table }
				r.tableCreate(options.table).run connection, (error) ->
					# suppress error (for pre-existing table)
					debug { table_exists: options.table } if error?
					callback null, connection

			# create a uuid to use for this emitter if required
			(connection, callback) ->
				if options.tag
					debug { using_uuid: options.tag }
					callback null, connection
				else
					r.uuid().run connection, (error, uuid) ->
						debug { created_uuid: uuid }
						options.tag = uuid
						callback error, connection

			# create changeset listener for incomming emit calls
			(connection, callback) ->
				debug { changeset_listener: options.tag }
				callback null, connection

		], (error) =>
			debug { options_table: @options.table }
			throw error if error?
			onceReady @options if onceReady?
			@resume()
			


	emit: (event, args...) ->
		debug { emit: event, args: args }
		@__push 'emit', arguments
		super event, args...
		return this

	__emit: (event, args..., done) ->
		__table = r.table @options.table
		__conn  = @options.connection

		debug { __emit: event, args: args, done: done.toString() }

		record = { tag: @options.tag, event: event, args: args }
		record.origin  = os.hostname() if @options.origin
		record.sent_at = r.now() if @options.timestamp

		test = __table.insert(record).run __conn, (error, results) ->
			throw error if error?

			debug { inserted: record, error: error, results: results }
			debug { done: done.toString() }
			done()


if require.main is module
	debug { testing: __filename }

	options = 
		host: '192.168.1.14'
		port:  28015
		db:   'dev'

	emitter = new RethinkEmitter options, (options) -> debug { event: 'constructor - ready', options: options }

	emitter.emit 'test', 'something'
	emitter.emit 'test2', 'something else'
	emitter.emit 'test3', 'another something'
	emitter.emit 'test3', 'another something'
	emitter.emit 'test3', 'another something'
	emitter.emit 'test3', 'another something'
	emitter.emit 'test3', 'another something'
	emitter.emit 'test3', 'another something'
	emitter.emit 'test3', 'another something'
	emitter.emit 'test3', 'another something'

