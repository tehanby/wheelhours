import unittest
from wheelhours.route_tracking import track_route

class TestRouteTracking(unittest.TestCase):

    def test_track_route_single_point(self):
        # Arrange
        start_point = "A"
        end_point = "B"
        expected_result = ["A", "B"]
        
        # Act
        result = track_route(start_point, end_point)
        
        # Assert
        self.assertEqual(result, expected_result)

    def test_track_route_multiple_points(self):
        # Arrange
        start_point = "A"
        end_point = "C"
        expected_result = ["A", "B", "C"]
        
        # Act
        result = track_route(start_point, end_point)
        
        # Assert
        self.assertEqual(result, expected_result)

    def test_track_route_no_path(self):
        # Arrange
        start_point = "X"
        end_point = "Y"
        expected_result = None
        
        # Act
        result = track_route(start_point, end_point)
        
        # Assert
        self.assertIsNone(result)

if __name__ == "__main__":
    unittest.main()
