//Thermoelectric power by Sieghardt Meldurson. Please message me in case of issues.
//The Hydro Turbine itself
#define THERMO_MAX_DIST 100
#define DEBRISMALFUNCTION 1
#define STALLMALFUNCTION 2
#define NOMALFUNCTION 0
/obj/machinery/power/thermoelectric
	name = "Thermoelectric turbine"
	desc = "A thermoelectric generator uses long metal rods to transfer heat from underground to the surface."
	icon = 'icons/obj/machines/thermoelectric.dmi'
	icon_state = "circ-unassembled"
	density = 1
	anchored = 1
	use_power = NO_POWER_USE
	idle_power_usage = 0
	active_power_usage = 0
	var/malfstate = NOMALFUNCTION //Our state regarding working. Are we malfunctioning?
	var/id = 0
	var/powrate = 10 //How much power * 10000 we produce per turbine.
	var/trickleout = 2 //How fast do we drain water when on.
	var/obj/machinery/power/thermoelectric_control/control = null

/obj/machinery/power/thermoelectric/drain_power()
	return -1

/obj/machinery/power/thermoelectric/update_icon()
	cut_overlays()
	if(!control)
		return
	if(malfstate)
		add_overlay(image('icons/obj/machines/thermoelectric.dmi', icon_state = "circ-hot", layer = FLY_LAYER))
	else if (control.working)
		add_overlay(image('icons/obj/machines/thermoelectric.dmi', icon_state = "circ-run", layer = FLY_LAYER))
	return

/obj/machinery/power/thermoelectric/proc/Malfunction()
	malfstate = rand(1,2)
	if(malfstate == DEBRISMALFUNCTION)
		desc = "A thermoelectric generator uses long metal rods to transfer heat from underground to the surface. This one seems to be important to the structural integrity around and is attached directly to the frame. There is debris blocking this turbine."
	else
		desc = "A thermoelectric generator uses long metal rods to transfer heat from underground to the surface. This one seems to be important to the structural integrity around and is attached directly to the frame. The turbine appears to be stalling out."
	control.workingturbines = control.workingturbines - 1
	control.malfturbines = control.malfturbines + 1
	return

/obj/machinery/power/thermoelectric/attackby(obj/item/I, mob/user)
	var/list/usable_qualities = list(QUALITY_PRYING,QUALITY_PULSING)
	var/tool_type = I.get_tool_type(user, usable_qualities, src)
	if(tool_type == QUALITY_PRYING && malfstate == DEBRISMALFUNCTION)
		if(I.use_tool(user, src, WORKTIME_NORMAL, tool_type, FAILCHANCE_EASY, required_stat = STAT_MEC))
			malfstate = 0
			desc = "A thermoelectric generator uses long metal rods to transfer heat from underground to the surface. This ones turbine fram has metal slag built up on its main frame, and has to by pry out."
			user.visible_message("[user] pried the debris from the generator's turbine.", "You pry away the blocking slag and dump the scrap which was in the way.")
			new /obj/item/trash/material/metal(get_turf(user))
			new /obj/item/trash/material/metal(get_turf(user))
			new /obj/item/trash/material/metal(get_turf(user))
			control.workingturbines = control.workingturbines + 1
			control.malfturbines = control.malfturbines - 1
			return
	if(tool_type == QUALITY_PULSING && malfstate == STALLMALFUNCTION)
		if(I.use_tool(user, src, WORKTIME_NORMAL, tool_type, FAILCHANCE_NORMAL, required_stat = STAT_MEC))
			malfstate = 0
			desc = "A thermoelectric generator uses long metal rods to transfer heat from underground to the surface. This one seems to be important to the structural integrity around and is attached directly to the frame."
			user.visible_message("[user] reset the generator's turbine.", "You reset the generator's turbine to its default working state.")
			control.workingturbines = control.workingturbines + 1
			control.malfturbines = control.malfturbines - 1
			return

/obj/machinery/power/thermoelectric/proc/set_control(var/obj/machinery/power/thermoelectric_control/TC)
	if(TC && (get_dist(src, TC) > THERMO_MAX_DIST))
		return FALSE
	control = TC
	return TRUE

/obj/machinery/power/thermoelectric/proc/unset_control()
	if(control)
		control.connected_turbines.Remove(src)
	control = null

/obj/machinery/power/thermoelectric/Process()
	update_icon()
	if(malfstate)
		return
	if(!control)
		return
	if(powernet && (powernet == control.powernet))
		if(control.working)
			if(control.waterheld <= 20)
				control.working = FALSE
				return
			var/sgen = powrate * 10000
			add_avail(sgen)
			control.gen += sgen
			control.waterheld = control.waterheld - trickleout

	else
		unset_control()

//The Thermoelectric Turbine Controller
/obj/machinery/power/thermoelectric_control
	name = "thermoelectric turbine control"
	desc = "A thermoelectric turbine control console."
	anchored = 1
	density = 1
	use_power = IDLE_POWER_USE
	icon = 'icons/obj/computer.dmi'
	icon_state = "computer"
	idle_power_usage = 250
	var/light_range_on = 1.5 //The light generated by the machine. Typical console lighting.
	var/light_power_on = 3
	var/id = 0
	var/waterheld = 0 //How much water there is at the moment in the 'basin'
	var/tricklein = 4 //How much water we trickle in every tick.
	var/watermax = 10000 //How much water can we hold?
	var/gen = 0 //To be used by UI to show how much we're generating.
	var/lastgen = 0 //To be used by UI to show how much we're generating.
	var/announced = 0 //Have we announced the basin being full already? Default no.
	var/tidechange = 0 //Every 100 ticks of this we change the trickle in.
	var/malfnumber = 0 //An ever increasing chance to malfunction as the machien functions.
	var/statusreport = "No Turbines Detected"
	var/working = FALSE //Are opened or not?
	var/workingturbines = 0
	var/malfturbines = 0
	var/obj/item/device/radio/radio
	var/list/connected_turbines = list()

/obj/machinery/power/thermoelectric_control/drain_power()
	return -1

/obj/machinery/power/thermoelectric_control/Initialize()
	. = ..()
	radio = new /obj/item/device/radio{channels=list("Terra")}(src)
	assign_uid()

/obj/machinery/power/thermoelectric_control/Destroy()
	qdel(radio)
	. = ..()

/obj/machinery/power/thermoelectric_control/proc/search_for_connected()
	if(!powernet)
		return
	for(var/obj/machinery/power/M in powernet.nodes)
		if(istype(M, /obj/machinery/power/thermoelectric))
			var/obj/machinery/power/thermoelectric/S = M
			if(!S.control)
				S.set_control(src)
				connected_turbines |= S
				if(S.malfstate == NOMALFUNCTION)
					workingturbines = workingturbines + 1
				else
					malfturbines = malfturbines + 1

/obj/machinery/power/thermoelectric_control/update_icon()
	if(stat & BROKEN)
		icon_state = "broken"
		cut_overlays()
		return
	if(stat & NOPOWER)
		icon_state = "c_unpowered"
		cut_overlays()
		return
	icon_state = "computer"
	cut_overlays()
	add_overlay(image('icons/obj/computer.dmi', "solar_screen"))
	return

/obj/machinery/power/thermoelectric_control/Process()
	if(stat & BROKEN)
		return
	lastgen = gen
	gen = 0
	statusreport = "There are [workingturbines] turbines in a functional state and [malfturbines] malfunctioning."
	if(!working && waterheld < 10000)
		tidechange = tidechange + 1
		announced = 0
		waterheld = waterheld + tricklein
		waterheld = CLAMP(waterheld, 0, 10000)
		if(tidechange == 100)
			tricklein = rand(4,9)
			if(malfnumber > rand(1,100))
				var/malftrigger = rand(1,workingturbines)
				connected_turbines[malftrigger]?:Malfunction()
				malfnumber = 0
			tidechange = 0
		return

	if(waterheld >= 10000 && !announced)
		radio.autosay("The Thermoelectric Generator holding tempture is now at maximum capacity.", "Thermoelectric Sensor", "Terra")
		announced = 1

/obj/machinery/power/thermoelectric_control/power_change()
	..()
	update_icon()

/obj/machinery/power/thermoelectric_control/nano_ui_interact(mob/user, ui_key = "hydroelectric", datum/nanoui/ui=null, force_open=NANOUI_FOCUS, var/datum/nano_topic_state/state = GLOB.default_state)

	if(stat & BROKEN)
		return

	if(!user)
		return

	//UI data
	var/data[0]
	data["waterheld"] = round(100.0*waterheld/watermax, 0.1)
	data["hydrostatus"] = statusreport
	data["isOpen"] = working
	data["generated"] = lastgen

	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new(user, src, ui_key, "hydroelectric.tmpl", "Thermoelectric Control Panel", 540, 380)
		// when the ui is first opened this is the data it will use
		ui.set_initial_data(data)
		// open the new ui window
		ui.open()
		// auto update every Master Controller tick
		ui.set_auto_update(TRUE)

/obj/machinery/power/thermoelectric_control/Topic(href, href_list)
	if(..())
		return 1

	if(href_list["togglegate"])
		togglegate()

	if(href_list["detectturbines"])
		src.search_for_connected()

/obj/machinery/power/thermoelectric_control/proc/togglegate()
	working = !working
	malfnumber = malfnumber + 10

/obj/machinery/power/thermoelectric_control/attack_hand(mob/user)
	nano_ui_interact(user)

/obj/item/paper/thermoelectric
	name = "paper- 'Working the Thermoelectric Generator.'"
	info = "<h1>Hey there.</h1><p>We've installed a whole new way of making power, namely a thermoelectric generator and it's as easy as they get to work with. \
	First thing first, click that button to detect the turbines, there should be ten of them. From that point onward it will be a waiting game. \
	The holding basin is pretty massive and the heat of the lava below can vary, so it may take a while for it to fill up. \
	You'll get a nifty notice over the radio communication channel once it's full. That would be the best time to open up the flood gates and start the turbines. \
	Water will start flowing and power will start being generated. Once it empties out it'll start filling back up on its own. \
	In the very rare case of a malfunction you'll have to suit up and head out to see what's wrong. You may have to use a multitool to \
	fix a stalled out engine or crowbar out some debris that gets stuck in. They'll have a red warning glow if malfunctioning. Good luck. -S.M .</p>"
