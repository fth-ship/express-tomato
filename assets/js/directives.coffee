clock = ($timeout) ->
  (scope, element, attrs) ->
    ringer = new Audio()

    ring = (showAlert = true) ->
      # ringing sound clip by xyzr_kx from
      # http://www.freesound.org/samplesViewSingle.php?id=14262
      # licensed under CC Sampling Plus 1.0
      ringer.play()
      ext = if ringer.canPlayType('audio/ogg') then 'ogg' else 'mp3'
      ringer = new Audio "../tomato.#{ext}"
      alert("Time's Up!") if showAlert
    ring false

    tick = ->
      return unless scope.timer.clock > 0
      if scope.timer.work isnt null
        --scope.timer.clock
      else
        ++scope.timer.clock
      if scope.timer.clock is 0
        ring scope.doAlert
        w = scope.timer.work
        w.stoppedAt = moment.utc().format()
        w.stoppedAtOffset = moment().zone()
        w.$save workId: w.id, taskId: w.TaskId
        scope.timer.work = null
        scope.hide()
      min = Math.floor scope.timer.clock / 60
      sec = scope.timer.clock - min * 60
      p = (x) -> if x < 10 then "0#{x}" else "#{x}"
      element.text "#{p min}:#{p sec}"

    schedule = ->
      work = ->
        tick()
        schedule()
      $timeout work, 1000
    schedule()

clock.$inject = ['$timeout']


angular.module('app.directives', [])
  .directive('clock', clock)
