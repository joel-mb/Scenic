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
EGO_SPEED = 20

## BEHAVIORS
behavior EgoBehavior(speed=10):

    do FollowLaneBehavior(speed) for 30 seconds
    terminate


## DEFINING SPATIAL RELATIONS
# Please refer to scenic/domains/driving/roads.py how to access detailed road infrastructure
# 'network' is the 'class Network' object in roads.py

lane = Uniform(*network.lanes)

ego = Car on lane.centerline,
    with behavior EgoBehavior(EGO_SPEED)

require (distance from ego to intersection) > 20
