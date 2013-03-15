require 'controllers'
require 'directives'
require 'filters'
require 'services'

angular.module('app', [
  'app.controllers'
  'app.directives'
  'app.filters'
  'app.services'
]).config([
  '$routeProvider'
  '$locationProvider'
  ($routeProvider, $locationProvider, config) ->
    $routeProvider
      .when('/', templateUrl: '/index.html', controller: 'TomatoCtrl')
      .when('/report', templateUrl: '/report.html', controller: 'ReportCtrl')
      .otherwise(redirectTo: '/')
    $locationProvider.html5Mode false
])

angular.element(document).ready ->
  angular.bootstrap document, ['app']
