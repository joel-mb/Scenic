""" Scenario Description
Based on 2019 Carla Challenge Traffic Scenario 09.
Ego-vehicle is performing a right turn at an intersection, yielding to crossing traffic.
"""

#SET MAP AND MODEL (i.e. definitions of all referenceable vehicle types, road library, etc)
param map = localPath('../../../tests/formats/opendrive/maps/CARLA/Town05.xodr')  # or other CARLA map that definitely works
param carla_map = 'Town05'
model scenic.simulators.carla.model

# CONSTANTS
EGO_DISTANCE_TO_INTERSECTION = Uniform(25, 30) * -1
ADV_DISTANCE_TO_INTERSECTION = Uniform(15, 20) * -1
SAFETY_DISTANCE = 20
BRAKE_INTENSITY = 1.0

## MONITORS
monitor TrafficLights:
   while True:
       if withinDistanceToTrafficLight(ego, 100):
           setClosestTrafficLightStatus(ego, "red")
       if withinDistanceToTrafficLight(adversary, 100):
           setClosestTrafficLightStatus(adversary, "green")
       wait

## DEFINING BEHAVIORS
behavior CrossingCarBehavior(trajectory):
	do FollowTrajectoryBehavior(trajectory = trajectory)
	terminate

behavior EgoBehavior(trajectory):
	try :
		do FollowTrajectoryBehavior(trajectory=trajectory)
	interrupt when withinDistanceToAnyObjs(self, SAFETY_DISTANCE):
		take SetBrakeAction(BRAKE_INTENSITY)


## DEFINING SPATIAL RELATIONS
# Please refer to scenic/domains/driving/roads.py how to access detailed road infrastructure
# 'network' is the 'class Network' object in roads.py

spawnAreas = []

# The meaning of filter() function is explained in examples/carla/Carla_Challenge/carlaChallenge7.scenic
fourWayIntersection = filter(lambda i: i.is4Way and i.isSignalized, network.intersections)

# make sure to put '*' to uniformly randomly select from all elements of the list
intersec = Uniform(*fourWayIntersection)
ego_start_lane = Uniform(*intersec.incomingLanes)

ego_maneuvers = filter(lambda i: i.type == ManeuverType.RIGHT_TURN, ego_start_lane.maneuvers)
ego_maneuver = Uniform(*ego_maneuvers)
ego_trajectory = [ego_maneuver.startLane, ego_maneuver.connectingLane, ego_maneuver.endLane]

adv_maneuvers = filter(lambda i: i.type == ManeuverType.STRAIGHT, ego_maneuver.conflictingManeuvers)
adv_maneuver = Uniform(*adv_maneuvers)
adv_trajectory = [adv_maneuver.startLane, adv_maneuver.connectingLane, adv_maneuver.endLane]

adv_start_lane = adv_maneuver.startLane

## OBJECT PLACEMENT
# Use the -1' index to get the last endpoint from the list of centerpoints in 'centerline'
ego_spawn_pt = ego_start_lane.centerline[-1]
adv_spawn_pt = adv_start_lane.centerline[-1]

ego = Car following roadDirection from ego_spawn_pt for EGO_DISTANCE_TO_INTERSECTION,
	with behavior EgoBehavior(ego_trajectory),
	with blueprint 'vehicle.lincoln.mkz2017'

adversary = Car following roadDirection from adv_spawn_pt for ADV_DISTANCE_TO_INTERSECTION,
	with behavior CrossingCarBehavior(adv_trajectory)

require (ego_maneuver.endLane == adv_maneuver.endLane)
