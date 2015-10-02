### 
@module  rethink-emitter
@version 1.0.0
@license MIT
@author  nullclick (Andy Brown) <andyb at formulatoast dot com>

@todo document this module and write tests for everything
###

os = require 'os'

Queuer = require './darkle/queuer'

async = require 'async'
debug = require('debug') 'rethink-emitter'
r     = require 'rethinkdb'


class RethinkEmitter extends Queuer

	constructor: (options, onceReady) ->
		super no # do not start queue automatically

		@options = options = options || {}
		@options.table     = options.table || 'events'

		@once 'ready', onceReady if typeof onceReady is 'function'
		@once 'ready', @resume

		async.waterfall [
			# connect to rethinkdb database server
			(callback) =>
				if options.connection
					debug { connecting: 'skip', connection: options.connection }
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

			# create an index on the tag field of records in the table
			(connection, callback) ->
				debug { creating_index: 'tag' }
				r.table(options.table).indexCreate('tag').run connection, (error, results) ->
					# suppress error (for pre-existing table index)
					debug { creating_index: error, results: results }
					callback null, connection
					
			# wait for secondary index on tag to become availabe
			(connection, callback) ->
				debug { indexWait: 'tag' }
				r.table(options.table).indexWait().run connection, (error, results) ->
					debug { indexWait: 'complete' }
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
			(connection, callback) =>
				debug { changeset_listener: options.tag }
				r.table(options.table)
					.getAll(options.tag, { index: 'tag' })
					.changes()
					.filter r.row('old_val').eq(null)
					.run connection, (error, cursor) =>
						callback error, connection

						cursor.on 'error', (error) -> throw error if error?

						cursor.on 'data', (item) =>
							event = item.new_val
							debug { change: event }
							@__local_emit event.event, event.args..., event

		], (error) =>
			debug { options_table: @options.table }
			@__local_emit 'error', error if error?
			@__local_emit 'ready', @options
			

	# internal emit method for triggering a local emit without
	# writing the event log to the transport or queueing it.
	# This can be used for process control events (ie. 'error' 
	# and 'ready' events) or for triggering the local emit when
	# one is seen over the transport.  Pretty much any time an
	# @emit would be called inside the class, it should use this
	# instead of the standard one to ensure that no transport
	# loops are created and that async does not try loading callbacks
	# that no longer exists, as was the problem before.
	__local_emit: (event, args...) ->
		debug { __local_emit: event, args: args }
		Queuer::emit.call @, event, args...

	emit: (event, args...) ->
		debug { emit: event, args: args }
		@__push 'emit', arguments
		#@__local_emit event, args...
		return this

	__emit: (event, args..., done) ->
		__table = r.table @options.table
		__conn  = @options.connection

		debug { __emit: event, args: args }

		record = { tag: @options.tag, event: event, args: args }
		record.origin  = os.hostname() if @options.origin
		record.sent_at = r.now() if @options.timestamp

		__table.insert(record).run __conn, (error, results) ->
			throw error if error?
			debug { inserted: record, error: error, results: results }
			done()


module.exports = RethinkEmitter




if require.main is module
	debug { testing: __filename }

	options = 
		host:     '192.168.1.14'
		port:      28015
		db:       'dev'
		origin:    yes
		timestamp: yes

	emitter = new RethinkEmitter options, (options) -> 
		debug { event: 'ready(constructor)', options: options }

	emitter.on 'ready', (options) ->
		debug { event: 'ready(emitter.on)', options: options }

		listener = new RethinkEmitter options, (options) ->
			debug { event: 'ready(listener)', options: options }

		listener.on 'test', (something, event) ->
			debug { received: 'test', event: event }

		listener.on 'test2', (something, event) ->
			debug { received: 'test2', event: event }

		listener.on 'test3', (something, event) ->
			debug { received: 'test3', event: event }

		emitter.emit 'test', 'something'
		emitter.emit 'test2', 'something else'
		emitter.emit 'test3', 'another something'

	emitter.on 'test', (something, event) ->
		debug { remitted: 'test', event: event }

	emitter.on 'test2', (something, event) ->
		debug { remitted: 'test2', event: event }

	emitter.on 'test3', (something, event) ->
		debug { remitted: 'test3', event: event }
