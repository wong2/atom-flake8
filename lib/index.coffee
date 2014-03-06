PyFlake8 = require './pyflake8'

module.exports =

  activate: ->
    @pyflake = new PyFlake8()

  deactivate: ->
    @pyflake.destroy()
