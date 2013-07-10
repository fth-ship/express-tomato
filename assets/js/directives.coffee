clock = ($timeout) ->
  (scope, element, attrs) ->
    ringer = new Audio()

    ring = (showAlert, playSound) ->
      # ringing sound clip by xyzr_kx from
      # http://www.freesound.org/samplesViewSingle.php?id=14262
      # licensed under CC Sampling Plus 1.0
      ringer.play() if playSound
      ext = if ringer.canPlayType('audio/ogg') then 'ogg' else 'mp3'
      ringer = new Audio "../tomato.#{ext}"
      alert("Time for a break!") if showAlert
    ring false, false

    tick = ->
      return unless scope.timer.clock > 0
      if scope.timer.work isnt null
        --scope.timer.clock
      else
        ++scope.timer.clock
      if scope.timer.clock is 0
        ring scope.$parent.doAlert, scope.$parent.doSound
        scope.finishWork()
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


# adapted from http://goodfil.ms/blog/posts/2012/08/13/angularjs-and-the-goodfilms-mobile-site-part-1/
doubleTap = ->
  (scope, element, attrs) ->
    tapping = false
    element.bind 'touchmove', -> tapping = false
    element.bind 'touchstart', ->
      if tapping
        scope.$apply(attrs['tomatoDbltap'])
        tapping = false
      else
        tapping = true


angular.module('app.directives', [])
  .directive('tomatoClock', clock)
  .directive('tomatoDbltap', doubleTap)

