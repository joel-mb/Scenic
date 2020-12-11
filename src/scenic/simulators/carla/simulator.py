
try:
	import carla
except ImportError as e:
	raise ModuleNotFoundError('CARLA scenarios require the "carla" Python package') from e

import math

from scenic.syntax.translator import verbosity
if verbosity == 0:	# suppress pygame advertisement at zero verbosity
	import os
	os.environ['PYGAME_HIDE_SUPPORT_PROMPT'] = 'hide'
import pygame

from scenic.domains.driving.simulators import DrivingSimulator, DrivingSimulation
from scenic.core.simulators import SimulationCreationError
from scenic.syntax.veneer import verbosePrint
import scenic.simulators.carla.utils.utils as utils
import scenic.simulators.carla.utils.visuals as visuals


class CarlaSimulator(DrivingSimulator):
	def __init__(self, carla_map, map_path, address='127.0.0.1', port=2000, timeout=10,
		         render=True, record=False, timestep=0.1, weather=None):
		super().__init__()
		verbosePrint('Connecting to CARLA...')
		self.client = carla.Client(address, port)
		self.client.set_timeout(timeout)  # limits networking operations (seconds)
		if carla_map is not None:
			self.world = self.client.load_world(carla_map)
		else:
			with open(map_path) as odr_file:
				self.world = self.client.generate_opendrive_world(odr_file.read())
		self.timestep = timestep

		if weather is not None:
			if isinstance(weather, str):
				self.world.set_weather(getattr(carla.WeatherParameters, weather))
			elif isinstance(weather, dict):
				self.world.set_weather(carla.WatherParameters(**weather))

		self.tm = self.client.get_trafficmanager()
		self.tm.set_synchronous_mode(True)

		# Set to synchronous with fixed timestep
		settings = self.world.get_settings()
		settings.synchronous_mode = True
		settings.fixed_delta_seconds = timestep  # NOTE: Should not exceed 0.1
		self.world.apply_settings(settings)
		verbosePrint('Map loaded in simulator.')

		self.render = render  # visualization mode ON/OFF
		self.record = record  # whether to save images to disk

	def createSimulation(self, scene, verbosity=0):
		return CarlaSimulation(scene, self.client, self.tm, self.timestep,
							   render=self.render, record=self.record,
							   verbosity=verbosity)

	def destroy(self):
		settings = self.world.get_settings()
		settings.synchronous_mode = False
		settings.fixed_delta_seconds = None
		self.world.apply_settings(settings)
		self.tm.set_synchronous_mode(False)

		super(CarlaSimulator, self).destroy()


class CarlaSimulation(DrivingSimulation):
	def __init__(self, scene, client, tm, timestep, render, record, verbosity=0):
		super().__init__(scene, timestep=timestep, verbosity=verbosity)
		self.client = client
		self.world = self.client.get_world()
		self.map = self.world.get_map()
		self.blueprintLib = self.world.get_blueprint_library()
		self.tm = tm
		
		# Reloads current world: destroys all actors, except traffic manager instances
		# self.client.reload_world()

		# Setup HUD
		self.render = render
		self.record = record
		if self.render:
			self.displayDim = (1280, 720)
			self.displayClock = pygame.time.Clock()
			self.camTransform = 0
			pygame.init()
			pygame.font.init()
			self.hud = visuals.HUD(*self.displayDim)
			self.display = pygame.display.set_mode(
				self.displayDim,
				pygame.HWSURFACE | pygame.DOUBLEBUF
			)
			self.cameraManager = None

		# Create Carla actors corresponding to Scenic objects
		self.ego = None
		for obj in self.objects:
			# Extract blueprint
			blueprint = self.blueprintLib.find(obj.blueprint)
			if obj.rolename is not None:
				blueprint.set_attribute('role_name', obj.rolename)

			# set walker as not invincible
			if blueprint.has_attribute('is_invincible'):
				blueprint.set_attribute('is_invincible', 'False')

			print("blueprint: ", blueprint)

			# Set up transform
			loc = utils.scenicToCarlaLocation(obj.position, world=self.world)
			rot = utils.scenicToCarlaRotation(obj.heading)
			transform = carla.Transform(loc, rot)
			transform.location.z += obj.elevation

			# Create Carla actor
			carlaActor = self.world.try_spawn_actor(blueprint, transform)
			if carlaActor is None:
				self.destroy()
				raise SimulationCreationError(f'Unable to spawn object {obj}')
			obj.carlaActor = carlaActor

			carlaActor.set_simulate_physics(obj.physics)

			if isinstance(carlaActor, carla.Vehicle):
				carlaActor.apply_control(carla.VehicleControl(manual_gear_shift=True, gear=1))
			elif isinstance(carlaActor, carla.Walker):
				carlaActor.apply_control(carla.WalkerControl())
				# spawn walker controller
				controller_bp = self.blueprintLib.find('controller.ai.walker')
				controller = self.world.try_spawn_actor(controller_bp, carla.Transform(), carlaActor)
				if controller is None:
					self.destroy()
					raise SimulationCreationError(f'Unable to spawn carla controller for object {obj}')
				obj.carlaController = controller

			# Check if ego (from carla_scenic_taks.py)
			if obj is self.objects[0]:
				self.ego = obj

				# Set up camera manager and collision sensor for ego
				if self.render:
					camIndex = 0
					camPosIndex = 0
					self.cameraManager = visuals.CameraManager(self.world, carlaActor, self.hud)
					self.cameraManager._transform_index = camPosIndex
					self.cameraManager.set_sensor(camIndex)
					self.cameraManager.set_transform(self.camTransform)
					self.cameraManager._recording = self.record

		self.world.tick() ## allowing manualgearshift to take effect 

		for obj in self.objects:
			if isinstance(obj.carlaActor, carla.Vehicle):
				obj.carlaActor.apply_control(carla.VehicleControl(manual_gear_shift=False))

		self.world.tick()

		# Set Carla actor's initial speed (if specified)
		for obj in self.objects:
			if obj.speed is not None:
				equivVel = utils.scenicSpeedToCarlaVelocity(obj.speed, obj.heading)
				obj.carlaActor.set_target_velocity(equivVel)

	def executeActions(self, allActions):
		super().executeActions(allActions)

		# Apply control updates which were accumulated while executing the actions
		for obj in self.agents:
			ctrl = obj._control
			if ctrl is not None:
				obj.carlaActor.apply_control(ctrl)
				obj._control = None

	def step(self):
		# Run simulation for one timestep
		self.world.tick()

		# Render simulation
		if self.render:
			# self.hud.tick(self.world, self.ego, self.displayClock)
			self.cameraManager.render(self.display)
			# self.hud.render(self.display)
			pygame.display.flip()

	def getProperties(self, obj, properties):
		# Extract Carla properties
		carlaActor = obj.carlaActor
		currTransform = carlaActor.get_transform()
		currLoc = currTransform.location
		currRot = currTransform.rotation
		currVel = carlaActor.get_velocity()
		currAngVel = carlaActor.get_angular_velocity()

		# Prepare Scenic object properties
		velocity = utils.carlaToScenicPosition(currVel)
		speed = math.hypot(*velocity)

		values = dict(
			position=utils.carlaToScenicPosition(currLoc),
			elevation=utils.carlaToScenicElevation(currLoc),
			heading=utils.carlaToScenicHeading(currRot),
			velocity=velocity,
			speed=speed,
			angularSpeed=utils.carlaToScenicAngularSpeed(currAngVel),
		)
		return values

	def destroy(self):
		for obj in self.objects:
			if obj.carlaActor is not None:
				if isinstance(obj.carlaActor, carla.Walker):
					obj.carlaController.stop()
					obj.carlaController.destroy()
				obj.carlaActor.destroy()
		if hasattr(self, "cameraManager"):
			self.cameraManager.destroy_sensor()

		self.world.tick()
		super(CarlaSimulation, self).destroy()
