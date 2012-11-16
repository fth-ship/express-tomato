class AppCtrl
  @$inject: ['$scope', '$location', '$resource', '$rootScope']

  constructor: ($scope, $location, $resource, $rootScope) ->
    $scope.pageTitle = 'App'
    $scope.$location = $location
    $scope.$watch '$location.path()', (path) -> $scope.activeNavId = path || '/'
    $scope.getClass = (id) ->
      if $scope.activeNavId.substring(0, id.length) is id then 'active' else ''

class TomatoCtrl
  @$inject: ['$scope']

  constructor: ($scope) ->
    $scope.pageTitle = 'Tomato'

    $scope.todos = [
      text: "learn angular", done: true
      text: "build an angular app", done: false
    ]

    $scope.addTodo = ->
      $scope.todos.push
        text: $scope.todoText
        done: false
      $scope.todoText = ""

    $scope.remaining = ->
      count = 0
      angular.forEach $scope.todos, (todo) ->
        count += (if todo.done then 0 else 1)
      count

    $scope.archive = ->
      oldTodos = $scope.todos
      $scope.todos = []
      angular.forEach oldTodos, (todo) ->
        $scope.todos.push todo  unless todo.done

class ReportCtrl
  @$inject: ['$scope']

angular.module('tomato.controllers', []).
  controller('AppCtrl', AppCtrl).
  controller('TomatoCtrl', TomatoCtrl).
  controller('ReportCtrl', ReportCtrl)
