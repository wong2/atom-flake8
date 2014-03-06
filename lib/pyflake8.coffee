{$, BufferedProcess} = require 'atom'
{Subscriber} = require 'emissary'
_ = require 'underscore-plus'

class PyFlake8

  SPLITTER: '@#@'

  constructor: ->
    atom.workspace.eachEditor (editor) =>
      @handleEvents editor

  destroy: ->
    @unsubscribe

  handleEvents: (editor) =>
    @subscribe atom.workspaceView, 'pane-container:active-pane-item-changed', =>
      @run(editor)

    buffer = editor.getBuffer()
    @subscribe buffer, 'saved', =>
      buffer.transact => @run(editor)
    @subscribe buffer, 'destroyed', =>
      @unsubscribe buffer

  run: (editor) =>
    file_path = editor.getUri()
    if not _.endsWith file_path, '.py'
      return

    split = @SPLITTER
    command = 'flake8'
    args = ["--format=%(row)s#{split}%(code)s#{split}%(text)s", file_path]
    
    stdout = stderr = (output) =>
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

    exit = (code) =>
      @resetState() if code == 0

    process = new BufferedProcess({command, args, stdout, stderr, exit})

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
    atom.workspaceView.eachEditorView (editorView) ->
      if editorView.active
        gutter = editorView.gutter
        gutter.removeClassFromAllLines 'atom-pyflakes-error'
        errors.forEach (error) ->
          gutter.addClassToLine error.row - 1, 'atom-pyflakes-error'


Subscriber.includeInto PyFlake8

module.exports = PyFlake8
