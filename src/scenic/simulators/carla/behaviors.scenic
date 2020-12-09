
from scenic.domains.driving.behaviors import *	# use common driving behaviors

try:
    from scenic.simulators.carla.actions import *
except ModuleNotFoundError:
    pass    # ignore; error will be caught later if user attempts to run a simulation

behavior WalkForwardBehavior():
	while True:
		take SetSpeedAction(0.5)

behavior CrossingActorSpeedControl(reference_actor, min_speed=1):

    while True:
        distance_vec = self.position - reference_actor.position
        rotated_vec = distance_vec.rotatedBy(-reference_actor.heading)

        ref_dist = rotated_vec.y
        actor_dist = rotated_vec.x

        ref_speed = reference_actor.speed
        ref_time = ref_speed / ref_dist

        actor_speed = actor_dist * ref_time
        if actor_speed < min_speed:
            actor_speed = min_speed

        print("---------------")
        print("Reference Dist: ", ref_dist)
        print("Actor Dist: ", actor_dist)
        print("Reference Speed: ", ref_speed)
        print("Reference Time: ", ref_time)
        print("Actor Speed: ", actor_speed)

        take SetWalkingSpeedAction(actor_speed)
