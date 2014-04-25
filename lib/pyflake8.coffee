{$} = require 'atom'
{Subscriber} = require 'emissary'
_ = require 'underscore-plus'
{exec} = require 'child_process'

class PyFlake8

  SPLITTER: '@#@'

  constructor: ->
    @PATH = atom.config.get('flake8.PATH') ? process.env.PATH
    atom.workspace.eachEditor (editor) =>
      @handleEvents editor

  destroy: ->
    @unsubscribe

  handleEvents: (editor) =>
    buffer = editor.getBuffer()
    events = 'saved contents-modified'
    @unsubscribe buffer
    @subscribe buffer, events, _.debounce((=> @run(editor)), 50)

  run: (editor) =>
    return if editor.getGrammar().name isnt 'Python'

    split = @SPLITTER
    command = "flake8 '--format=%(row)s#{split}$(code)s#{split}%(text)s' -"
    options = {env: {@PATH}}

    handleOutput = (output) =>
      errors = @parsePyFlake8Output output
      if errors.length
        @updateGutter errors
        @subscribe atom.workspaceView, 'cursor:moved', =>
          if editor.cursors[0]
            @updateStatus errors, editor.cursors[0].getBufferRow()
        @subscribe editor, 'scroll-top-changed', =>
          @updateGutter errors
      else
        @resetState()

    editorView = atom.workspaceView.getActiveView()
    editorView.resetDisplay();
    editorView.gutter.find('atom-pyflakes-error').removeClass('atom-pyflakes-error')

    flake8 = exec command, options, (error, stdout, stderr) =>
      @resetState() unless error
      handleOutput stdout
      handleOutput stderr
    flake8.stdin.end editor.getText()

  parsePyFlake8Output: (output) ->
    output = $.trim(output)
    lines = output.split('\n')
    errors = []
    for line in lines
      [row, code, text] = line.split(@SPLITTER)
      row = parseInt row, 10
      errors.push {row, code, text}
    return errors

  resetState: (editor) ->
    @updateStatus null
    @updateGutter []
    atom.workspaceView.off 'cursor:moved'
    @unsubscribe editor

  updateStatus: (errors, row) =>
    status = $('#pyflakes-status')
    status.remove() if status
    if !errors or row < 0
      return

    lineErrors = errors.filter (error) ->
      error.row == row + 1

    if lineErrors.length > 0
      error = lineErrors[0]
      msg = "Error: #{error.row}: #{error.text}"
    else
      msg = errors.length ? errors.length + ' PyFlakes errors' : ''

    html = '<span id="pyflakes-status" class="inline-block">' + msg + '</span>'
    atom.workspaceView.statusBar.appendLeft html

  updateGutter: (errors) ->
    editor = atom.workspace.getActiveEditor()
    editorView = atom.workspaceView.getActiveView()
    gutter = editorView.gutter
    errors.forEach (error) ->
      gutter.addClassToLine error.row - 1, 'atom-pyflakes-error'


Subscriber.includeInto PyFlake8

module.exports = PyFlake8
