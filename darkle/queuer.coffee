### 
@module  queuer
@version 0.0.1
@license MIT
@author  nullclick (Andy Brown) <andyb at formulatoast dot com>
###

async = require 'async'
debug = require('debug') 'darkle:queuer-object'

Darkle = require __dirname + '/darkle'


###
@class Queuer
@extends Darkle
@darkle core v0.0.1

@description
	Simple object that provides a execution queue that allows adding
	of methods that use the execution queue.  Useful when you may be
	calling the methods before a backend is ready.  It can be easily
	be extended to provide an object that can heal itself on errors.
###
class Queuer extends Darkle


	###
	@constructor
	@param {boolean=yes} running - should the queue start running immediately
	###
	constructor: (running = yes) ->
		super

		@__queue = async.queue (task, callback) =>
			args = Array::slice.call task.args
			done = =>
				debug { done: task.method }
				callback null
			debug { dispatch: task.method, args: args }
			@[task.method].apply @, args.concat done

		@__queue.pause() unless running


	###
	Resume processing of the queue.
	###
	resume: -> 
		debug { resuming: @__queue.length() }
		@__queue.resume()


	###
	Add a method call to the processing queue.

	@private
	@param {string} name - name of method that will be called
	@param {Array}  args - array of arguments to pass to method

	@example
		emit: (event, args...) ->
			debug { emit: event, args: args }
			@__push 'emit', args
			super event, args...
	###
	__push: (name, args) ->
		debug { method: 'Queuer#__push', name: name, args: args }
		@__queue.push { method: "__#{name}", args: args }


	###
	Create a queued method.  This creates a method for the object
	that queues all calls to be run when the queue processes it and
	an internal method that does the actual work.

	All methods added in this manner are expected to have their own
	callback of the form (error, args..., done) and must call `done()`
	when their execution allows for it so the queue can continue.

	@todo maybe introduce a timeout for checking that `done()` is
		actually called at some point should be optional though

	@todo create documentation generator that uses the doctring that
		is passed to this method for better traceability

	@param {string} name      - the interface method name
	@param {string} docstring - documentation for the method, unused
	@param {function} method  - actuall worker to run during processing
	###
	method: (name, docstring, method) ->
		# should export documentation in some manner
		debug { method: 'Queuer#method', name: name, docs: docstring }

		# check to ensure that we are not overwritting an existing method
		# if such behaviour is desired, the methods can be set directly
		if @hasOwnProperty name
			error = new RangeError "'#{name}' is already defined"
			@emit 'error', error, { name: name, docstring: docstring }
			return this

		if @hasOwnProperty "__#{name}" 
			error = new RangeError "'#{name}'' would overwrite '__#{name}'"
			@emit 'error', error, { name: name, docstring: docstring }
			return this

		# create interface method used by consumers of this object
		# it simply pushes a task record into the queue to process
		@[name] = -> @__push name, arguments

		# Create the internal method that is run when the queue
		# processes the call.  Attach the `done()` function and 
		# return true so that done() can be chained when called
		# ie. return done() and callback null
		@["__#{name}"] = (args..., done) ->  method args..., -> done() or yes

		@emit 'method-added', name, method

		return this


module.exports = Queuer




if require.main is module
	debug { testing: __filename }

	qr_simple = new Queuer()

	# add a simple do nothing method
	qr_simple.method 'test', "simple method add test", (callback, done) -> 
		debug { running_method: 'test' }
		return callback(null, 'something') or done()

	qr_simple.test (error, results) ->
		debug { callback_for: 'test', error: error, results: results }

	# make sure it emits an error if we try to override a method
	qr_simple.on 'error', (error, stuff) ->
		debug { listener: 'error overwritting', error: error, stuff: stuff }

	qr_simple.method 'test', "simple method overwritting test", (callback, done) -> 
		debug { running_method: 'test overwrite' }
		return  callback(null, 'something') or done()

	qr_simple.method 'queue', "try overwritting __queue via 'queue'", (callback, done) ->
		debug { running_method: '__queue overwrite' }
		return callback(null, 'something') or done()

	qr_simple.method '__queue', "try overwritting __queue", (callback, done) ->
		debug { running_method: '__queue overwrite' }
		return callback(null, 'something') or done()


	qr_wait = new Queuer no

	# add a simple do nothing method
	qr_wait.method 'test', "simple method add test", (callback, done) -> 
		debug { running_method: 'test' }
		return callback(null, 'something') or done()

	qr_wait.test (error, results) ->
		debug { callback_for: 'test call 1', error: error, results: results }

	qr_wait.test (error, results) ->
		debug { callback_for: 'test call 2', error: error, results: results }

	qr_wait.test (error, results) ->
		debug { callback_for: 'test call 3', error: error, results: results }

	qr_wait.resume()
