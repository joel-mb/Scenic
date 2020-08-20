from scenic.domains.driving.network import loadNetwork
loadNetwork('/home/carla_challenge/Desktop/Carla/Dynamic-Scenic/Scenic-devel-099/examples/carla/OpenDrive/Town01.xodr')

param map = localPath('../OpenDrive/Town03.xodr')
param carla_map = 'Town03'

from scenic.domains.driving.behaviors import *

model scenic.domains.driving.model


# 3 way intersection. ego goes straight. actor has right of way.

param time_step = 1.0/10

# CONSTANTS
space = [2,3,4,5]

# GEOMETRY
threeWayIntersections = filter(lambda i: i.is3Way, network.intersections)
intersection = Uniform(*threeWayIntersections)

straight_maneuvers = filter(lambda m: m.type == ManeuverType.STRAIGHT, intersection.maneuvers)
straight_maneuver = Uniform(*straight_maneuvers)

startLane = straight_maneuver.startLane
connectingLane = straight_maneuver.connectingLane
endLane = straight_maneuver.endLane

centerlines = [startLane.centerline, connectingLane.centerline, endLane.centerline]
egoStart = (OrientedPoint at startLane.centerline[-1]) offset by (-2, 2) @ 0 

# --

conflicting_lefts = filter(lambda m: m.type == ManeuverType.LEFT_TURN, straight_maneuver.conflictingManeuvers)
leftTurn_maneuver = Uniform(*conflicting_lefts)

L_startLane = leftTurn_maneuver.startLane
L_connectingLane = leftTurn_maneuver.connectingLane
L_endLane = leftTurn_maneuver.endLane

L_centerlines = [L_startLane.centerline, L_connectingLane.centerline, L_endLane.centerline]
actorStart = (OrientedPoint at L_startLane.centerline[-1]) offset by (-2, 2) @ 0 

# BEHAVIOR
behavior EgoBehavior(target_speed=20, trajectory = None):
	assert trajectory is not None
	brakeIntensity = 0.7

	try: 
		FollowTrajectoryBehavior(target_speed=15, trajectory=trajectory)

	interrupt when distanceToAnyCars(car=self, thresholdDistance=10):
		take SetBrakeAction(brakeIntensity)


# PLACEMENT
ego = Car following roadDirection from egoStart by -Uniform(*space),
		with blueprint 'vehicle.tesla.model3',
		with behavior EgoBehavior(target_speed=15, trajectory=centerlines)

other = Car following roadDirection from actorStart by -Uniform(*space),
		with blueprint 'vehicle.tesla.model3',
		with behavior FollowTrajectoryBehavior(target_speed=5, trajectory=L_centerlines)