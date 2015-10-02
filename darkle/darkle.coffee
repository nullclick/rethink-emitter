### 
@module  darkle
@version 0.0.1
@license MIT
@author  nullclick (Andy Brown) <andyb at formulatoast dot com>
###

EventEmitter = require 'events'

debug = require('debug') 'darkle:darkle'


###
@class Darkle
@extends EventEmitter
@darkle core v0.0.1

@description
	Provides the Darkle class, a simple EventEmitter to provide a way
	for methods to be added to the object hierarchy. All classes in
	the darkle library extend this class.  At the moment it doesn't
	provide any functionality besides being an EventEmitter.
###
class Darkle extends EventEmitter

	constructor: ->
		super

module.exports = Darkle
