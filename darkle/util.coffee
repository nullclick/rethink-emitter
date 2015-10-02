### 
@module  util
@version 0.0.1
@license MIT
@author  nullclick (Andy Brown) <andyb at formulatoast dot com>

@todo write proper unit tests for all methods and use cases

@description
	Utility functions used throughout the darkle library.  It adds a 
	small collection of functions to the nodejs util module just to 
	keep usage easy.  @note some of them have bad names (ie. `$`)
###

debug = require('debug') 'darkle:util'


module.exports = util = require 'util'


### 
Simple function to mix a given module's methods into the prototype
of the given class.  An optional arracy of methods to attach can be
passed, otherwise all module methods will be attached.  It does not
have to be called in the class definition, as long as the given
klass has a prototype that can be attacked to it should work fine.

@darkle util v0.0.1

@example
	a_module = { a: ->, b: -> }
	class Something
		mixin Something, a_module
###
util.mixin = (klass, module, attach = []) ->
	debug { klass: klass, module: module, attach: attach }
	if attach.length is 0
		attach.push method for own method of module
	for own method of module when method in attach
		debug { mixin: 'attaching', method: method }
		klass::[method] = module[method] 


###
This is meant to be passed the arguments object from within a function
where there are optional (or just an unknown number of) arguments.  It
normally isn't used directly, but by action queuers where the methods
that get queued have all sorts of function signatures.

@darkle util v0.0.1

@example
	test = (error, something, callback) ->
		[ callback, error, rest... ] = de_arg arguments
		___ { callback, error, rest }
	test 1, 2, 3, 4 # { callback: 1, error, 2, rest: [3, 4] }
###
util.de_arg = (k) -> 
	args = Array::slice.call(k)
	args[..-1] = args.pop()
	return args




if require.main is module
	debug { testing: __filename }

	assert = require 'assert'

	debug { testing: 'util.mixin' }
	test_module = 
		a: -> debug { test_module: 'a' }
		b: -> debug { test_module: 'b' }
		c: -> debug { test_module: 'c' }

	class MixinTest_1
		util.mixin MixinTest_1, test_module

	mixin_test_1 = new MixinTest_1()
	assert mixin_test_1.a, "class should have 'a' method mixed in"
	assert mixin_test_1.b, "class should have 'b' method mixed in"
	assert mixin_test_1.c, "class should have 'c' method mixed in"

	class MixinTest_2
		util.mixin MixinTest_2, test_module, ['b']

	mixin_test_2 = new MixinTest_2()
	assert mixin_test_2.b, "class should have 'b' method mixed in"
	assert !mixin_test_2.a, "class should not have 'a' method mixed in"
	assert !mixin_test_2.c, "class should not have 'c' method mixed in"


	debug { testing: 'util.$' }
	# example of simple use as a callback rotator
	$_test_1 = (a, b, c) ->
		debug { $_test_1: arguments, after: util.de_arg arguments }
		[_cb, _a, _b] = util.de_arg arguments
		switch arguments.length
			when 3
				assert _cb is c, "'cb' should be moved to front"
				assert _a is a, "'a' should be moved correctly"
				assert _b is b, "'b' should be moved correctly"
			when 2
				assert _cb is b, "'cb' should be moved to front"
				assert _a is a, "'a' should be moved correctly"
			when 1
				assert _cb is a, "'cb' should be moved to front"
			when 0
				assert _cb is undefined, "'_cb' should be undefined"
			else
				assert arguments[arguments.length - 1] is _cb, "'cb' should be moved to front"

	$_test_1 1, 2, ->
	$_test_1 1, ->
	$_test_1 ->
	$_test_1()
	$_test_1 1, 2, 3, 4, ->

	# example of argument splatting
	$_test_2 = ->
		debug { $_test_2: arguments, after: util.de_arg arguments }
		[head, tail...] = util.de_arg arguments

		debug { head: head, tail: tail }

		last_arg = arguments[arguments.length - 1]

		switch arguments.length
			when 0
				assert head is undefined, "'head' should be undefined"
				assert tail.length is 0, "'tail' should be empty"
			else
				assert head is last_arg, "'head' should be the last argument"
				assert tail.length is arguments.length - 1, "'tail' should have #{arguments.length - 1} values"

	$_test_2()
	$_test_2 ->
	$_test_2 1, ->
	$_test_2 1, 2, ->
	$_test_2 1, 2, 3, ->
	$_test_2 1, 2, 3, 4, ->
	$_test_2 1, 2, 3, 4, 5, ->
