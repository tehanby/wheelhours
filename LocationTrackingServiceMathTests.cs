using System;
using Xunit;

public class LocationTrackingServiceMathTests
{
    [Fact]
    public void TestAccumulateDistanceFromHighAccuracyFixesOnly()
    {
        // Arrange
        var locationTracker = new LocationTrackingService();
        var highAccuracyFix = new Location { Accuracy = 10 }; // Assuming 10 meters is considered high accuracy
        var lowAccuracyFix = new Location { Accuracy = 50 }; // Assuming 50 meters is considered low accuracy

        // Act
        locationTracker.AccumulateDistance(highAccuracyFix);
        locationTracker.AccumulateDistance(lowAccuracyFix);

        // Assert
        Assert.Equal(10, locationTracker.TotalDistance); // Only the high-accuracy fix should be counted
    }

    // Other tests...
}

public class LocationTrackingService
{
    public double TotalDistance { get; private set; }

    public void AccumulateDistance(Location location)
    {
        if (location.Accuracy <= 10) // High accuracy threshold
        {
            TotalDistance += GetDistanceFromLastFix(location);
        }
    }

    private double GetDistanceFromLastFix(Location currentLocation)
    {
        // Simplified distance calculation logic
        return Math.Abs(currentLocation.Latitude - GetLastKnownLocation().Latitude) + 
               Math.Abs(currentLocation.Longitude - GetLastKnownLocation().Longitude);
    }

    private Location GetLastKnownLocation()
    {
        // Mock implementation to return a dummy location
        return new Location { Latitude = 0, Longitude = 0 };
    }
}

public class Location
{
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public int Accuracy { get; set; }
}
