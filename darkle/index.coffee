### 
@version 0.0.1
@license MIT
@author  nullclick (Andy Brown) <andyb at formulatoast dot com>

@description
	Darkle core library, pulls in all the objects and exports them.
###

@util   = require __dirname + '/util'
@Darkle = require __dirname + '/darkle'
@Queuer = require __dirname + '/queuer'




if require.main is module
	assert = require 'assert'
	debug  = require('debug') 'darkle:index'

	debug { testing: __filename }
	assert module.exports.util
	assert module.exports.Darkle
	assert module.exports.Queuer
