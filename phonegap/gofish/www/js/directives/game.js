goFish.directive("game", [function(){

	return {
		restrict: "E",
		templateUrl: "./partials/game.html",
		scope: {},
		controller: function($http, $scope, GameService) {
			// Functions
			$scope.updateLevel = function() {
				$scope.level = GameService.getCurrentLevel();
			};

			$scope.moveLeft = function() {
				GameService.move("left");
			};

			$scope.moveRight = function() {
				GameService.move("right");
			};

			$scope.fish = function() {
				GameService.fish();
			};

			$scope.end = function() {
				GameService.endLevel();
			};

			// Initialisation
			$scope.updateLevel();

			// Watch for level updates
			$scope.$on("levelStarted", function() {
				$scope.updateLevel();
			});
			$scope.$on("levelUpdated", function() {
				$scope.updateLevel();
			});
		},
		controllerAs: "gameCtrl"
	};

} ]);
