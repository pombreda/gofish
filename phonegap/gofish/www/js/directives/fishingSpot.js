goFish.directive("fishingSpot", [function(){

	return {
		restrict: "E",
		templateUrl: "./partials/fishingSpot.html",
		scope: {},
		controller: function($scope, GameService) {
			// Functions
			$scope.updateFishingSpot = function() {
				var currentLevel = GameService.getCurrentLevel();
				if (currentLevel.level && (currentLevel.level.position >= 0) && currentLevel.level.map && currentLevel.cues && currentLevel.level.name) {
					// Update variables
					$scope.position = currentLevel.level.position;
					$scope.map = currentLevel.level.map[0];
					$scope.cues = currentLevel.cues;
					// Remove spaces for css image selection
					$scope.level = (currentLevel.level.name).replace(/\s/g, '');

					// Generate an array to traverse with ng-repeat to draw depth levels
					var depth = $scope.map[$scope.position];
					$scope.currentDepth = [];
					for (var i = 1; i <= depth; i++) {
						$scope.currentDepth.push(i);
					};

					// Check left and right depths to draw some depth cues for left and right
					// Draw depth cues one depth lower than can fish
					$scope.cueDepth = (depth + 1);
					// Left
					if ($scope.position == 0 || $scope.map[$scope.position - 1] < depth) {
						$scope.leftDepthCue = "up";
					} else if ($scope.map[$scope.position - 1] > depth) {
						$scope.leftDepthCue = "down";
					} else {
						$scope.leftDepthCue = "level";
					}
					// Right
					if ($scope.position == 19 || $scope.map[$scope.position + 1] < depth) {
						$scope.rightDepthCue = "up";
					} else if ($scope.map[$scope.position + 1] > depth) {
						$scope.rightDepthCue = "down";
					} else {
						$scope.rightDepthCue = "level";
					}
				}
				else {
					console.log("ERROR finding necessary information for rendering fishing spot");
				}
			};

			$scope.redrawCueDepth = function() {
				// ng-style was not updating the background image for the cue depth
				// force css update
				$('#cueDepth').css('background-image', "url('./img/levels/"+$scope.level+"/"+$scope.cueDepth+".png')");
			}

			$scope.fish = function() {
				GameService.fish();
				$scope.showHint = false;
			};

			// Listen for level updates
			$scope.$on("levelStarted", function() {
				$scope.updateFishingSpot();
			});
			$scope.$on("levelUpdated", function() {
				$scope.updateFishingSpot();
			});
			$scope.$on("moved", function() {
				$scope.redrawCueDepth();
			});
			$scope.$on("levelEnded", function() {
				// On starting next level, initial cueDepth must be calculated
				delete $scope.cueDepth;
				$scope.showHint = true;
			});


			// Initialisation
			$scope.map = null;
			$scope.position = 0;
			$scope.cues = null;
			$scope.currentDepth = [];
			$scope.leftDepthCue = null;
			$scope.rightDepthCue = null;
			$scope.showHint = true;
		},
		controllerAs: "fishingSpotCtrl"
	};

} ]);
