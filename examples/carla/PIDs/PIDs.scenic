""" Scenario Description
Traffic Scenario 05.
Lane changing to evade slow leading vehicle.
The ego-vehicle performs a lane changing to evade a leading vehicle,
which is moving too slowly.
"""

## SET MAP AND MODEL (i.e. definitions of all referenceable vehicle types, road library, etc)
param map = localPath('../../../tests/formats/opendrive/maps/CARLA/Town04.xodr')  # or other CARLA map that definitely works
param carla_map = 'Town04'
model scenic.simulators.carla.model

## CONSTANTS
EGO_MODEL = "vehicle.lincoln.mkz2017"
EGO_SPEED = 30

LEAD_CAR_SPEED = 0

DIST_THRESHOLD = 25
BYPASS_DIST = 25

## BEHAVIORS
behavior EgoBehavior(speed=10):
    try: 
        do FollowLaneBehavior(speed)

    interrupt when withinDistanceToAnyObjs(self, DIST_THRESHOLD):
        # change to left (overtaking)
        left_section = self.laneSection.laneToLeft
        is_opposite = self.laneSection.isForward != left_section.isForward 
        do LaneChangeBehavior(laneSectionToSwitch=left_section, is_oppositeTraffic=is_opposite, target_speed=speed)
        do FollowLaneBehavior(speed, is_oppositeTraffic=is_opposite, laneToFollow=left_section.lane) until (distance to lead) > BYPASS_DIST

        # change to right
        right_section = self.laneSection.laneToRight
        do LaneChangeBehavior(laneSectionToSwitch=right_section, target_speed=speed)
        do FollowLaneBehavior(speed) for 15 seconds
        terminate

behavior LeadingCarBehavior(speed=3):
    do FollowLaneBehavior(speed)

## DEFINING SPATIAL RELATIONS
# Please refer to scenic/domains/driving/roads.py how to access detailed road infrastructure
# 'network' is the 'class Network' object in roads.py

lane = Uniform(*network.lanes)

ego = Car on lane.centerline,
    with behavior EgoBehavior(EGO_SPEED)

lead = Car following roadDirection from ego for Range(100, 110),
    with behavior LeadingCarBehavior(LEAD_CAR_SPEED)

require (distance from ego to intersection) > 20
require (distance from lead to intersection) > 20
require always (lead.laneSection._laneToLeft is not None) and (lead.laneSection.isForward == lead.laneSection._laneToLeft.isForward)
