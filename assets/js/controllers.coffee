TimerCtrl = ($scope, Work, Break) ->
  T = $scope.timer =
    clock: 0
    name: null
    work: null
    brake: null

  E = $('#timer')

  show = ->
    E.css top: '20%'
    E.modal('show').on 'hidden', ->
      E.css top: -1000
      Work.remove(workId: T.work.id, taskId: T.work.taskId) if T.work
      Break.remove(breakId: T.brake.id) if T.brake

  $scope.hide = ->
    E.modal('hide')
    E.css top: -1000

  $scope.finishBreak = ->
    T.brake.stop_utc = moment.utc().format()
    T.brake.stop_zone = moment().zone()
    T.brake.stop_lat = $scope.$parent.geo.latitude
    T.brake.stop_lng = $scope.$parent.geo.longitude
    T.brake.stop_acc = $scope.$parent.geo.accuracy
    T.brake.$save breakId: T.brake.id, ->
      T.brake = null
      $scope.hide()

  $scope.finishWork = ->
    T.work.stop_utc = moment.utc().format()
    T.work.stop_zone = moment().zone()
    T.work.stop_lat = $scope.$parent.geo.latitude
    T.work.stop_lng = $scope.$parent.geo.longitude
    T.work.stop_acc = $scope.$parent.geo.accuracy
    T.work.$save workId: T.work.id, taskId: T.work.taskId, ->
      T.work = null
      $scope.hide()

  $scope.$on 'start:work', (event, work) ->
    sec = 60 * $scope.tomato.workMin
    elapsed = moment.utc().diff moment.utc work.start_utc
    T.clock = sec - Math.floor elapsed / 1000
    T.work = work
    T.brake = null
    T.name = (t.name for t in $scope.tasks when t.id is work.taskId)[0]
    show()

  $scope.$on 'start:break', (event, brake) ->
    elapsed = moment.utc().diff moment.utc brake.start_utc
    T.clock = Math.max 1, Math.floor elapsed / 1000
    T.name = brake.name
    T.work = null
    T.brake = brake
    show()

  $scope.hide()

TimerCtrl.$inject = ['$scope', 'Work', 'Break']


TomatoCtrl = ($scope, $timeout, Tomato, Task, Work, Break) ->
  $('.tipped').tooltip placement: 'bottom'

  $scope.tomato = Tomato.get()
  $scope.tasks = Task.query()

  $scope.doAlert = true
  $scope.doSound = true
  $scope.geo = null

  $scope.toggleGeo = ->
    if $scope.geo is null
      $scope.geo = {}
    else
      $scope.geo = null
    if $scope.doGeo isnt null
      navigator.geolocation.getCurrentPosition (geoloc) ->
        $scope.geo = geoloc.coords
        console.log $scope.geo

  $scope.toggleGeo()

  $scope.breaks = Break.query ->
    for brake in $scope.breaks
      continue if brake.stop_utc > brake.start_utc
      $scope.$broadcast 'start:break', brake
      break

  $scope.works = Work.query ->
    earliest = moment.utc().subtract $scope.tomato.workMin, 'minutes'
    for work in $scope.works
      continue unless work.stop_utc < work.start_utc
      cr = moment.utc work.start_utc
      if cr < earliest
        work.$remove(workId: work.id, taskId: work.taskId)
      else
        $scope.$broadcast 'start:work', work
        break

  $scope.ui =
    filter: ''
    order: (t) ->
      finish = if t.finish_utc > t.create_utc then '1' else '0'
      "#{finish}:#{9-t.priority}:#{t.create_utc}"
    edit: false
    task: new Task(name: '', priority: 0, difficulty: 0)
    brake: new Break(name: 'quick')

  $scope.edit = ->
    $scope.ui.edit = not $scope.ui.edit
    $timeout($('#slug').select, 100) if $scope.ui.edit

  $scope.update = ->
    Tomato.save $scope.tomato, (t) ->
      [_, p, _, s] = window.location.href.match /^(.+?)\/([^\/]+)\/(\#.+)$/
      url = "#{p}/#{encodeURIComponent $scope.tomato.slug}/"
      window.location.href = if s then "#{url}#{s}" else url
      $scope.ui.edit = false

  $scope.remove = ->
    Tomato.remove $scope.tomato, (t) ->
      [_, p, _, _] = window.location.href.match /^(.+?)\/([^\/]+)\/(\#.+)$/
      window.location.href = p

  $scope.addTask = ->
    return if $scope.ui.task.name is ''
    Task.save $scope.ui.task, (task) ->
      $scope.tasks.push task
      $scope.ui.task = new Task name: '', priority: 0, difficulty: 0
      $timeout $('#cr').select, 100

  $scope.startBreak = ->
    $scope.ui.brake.start_utc = moment.utc().format()
    $scope.ui.brake.start_zone = moment().zone()
    $scope.ui.brake.start_lat = $scope.geo.latitude
    $scope.ui.brake.start_lng = $scope.geo.longitude
    $scope.ui.brake.start_acc = $scope.geo.accuracy
    Break.save $scope.ui.brake, (brake) ->
      $scope.ui.brake = new Break name: 'quick'
      $scope.$broadcast 'start:break', brake

  $('#cr').select()

TomatoCtrl.$inject = ['$scope', '$timeout', 'Tomato', 'Task', 'Work', 'Break']


TaskCtrl = ($scope, Work) ->
  task = $scope.$parent.task

  $scope.works = ->
    (w for w in $scope.$parent.works when w.taskId is task.id)

  $scope.flag = ->
    return if task.finish_utc > task.create_utc
    task.priority = if task.priority is 0 then 1 else 0
    task.$save taskId: task.id

  $scope.start = ->
    return if task.finish_utc > task.create_utc
    w = new Work
      start_utc: moment.utc().format()
      start_zone: moment().zone()
      start_lat: $scope.$parent.geo.latitude
      start_lng: $scope.$parent.geo.longitude
      start_acc: $scope.$parent.geo.accuracy
    w.$save taskId: task.id, (w) ->
      $scope.$parent.$parent.$broadcast 'start:work', w

  $scope.remove = ->
    return if task.finish_utc > task.create_utc
    task.$remove taskId: task.id

  $scope.finish = ->
    if task.finish_utc is null or task.finish_utc <= task.create_utc
      task.finish_utc = moment.utc()
    else
      task.finish_utc = moment.utc(0)
    task.$save taskId: task.id

TaskCtrl.$inject = ['$scope', 'Work']


angular.module('app.controllers', ['app.services'])
  .controller('TomatoCtrl', TomatoCtrl)
  .controller('TaskCtrl', TaskCtrl)
  .controller('TimerCtrl', TimerCtrl)
