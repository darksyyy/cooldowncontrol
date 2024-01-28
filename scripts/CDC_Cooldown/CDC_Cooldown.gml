/**
	Cooldown Control
	Author: Darcy Shaw
*/

/// @function			CDC_Cooldown
/// @description		Struct holding cooldown properties
function CDC_Cooldown() constructor
{
	__on_start = undefined; // Function to execute on start
	__on_end = undefined;	// Function to execute on end
	__name = undefined;		// Name of the Cooldown
	__duration = undefined;	// Cooldown Time in (__units)
	__units = undefined;	// Unit of Time (seconds or frames)
	__state = CDC_STATE.READY;	// Current State of the Cooldown
	__ts = undefined;		// Time source
	__cdr = undefined;		// Cooldown Reduction
	
	toString = function()
	{
		return $"CDC_COOLDOWN: \'{__name}\', \'{__duration}\', \'{__units}\'";	
	}
}

/// @function			CDC_Manager
/// @description		Manages Cooldowns
function CDC_Manager() constructor 
{
	__context = other;					// Execution context for ALL cooldown functions
	__cooldowns = ds_map_create();		// Map containing Names -> Cooldown Structs
	
	/// @function			_add(_name, _on_start, _on_end, _duration, _units)
	/// @description		(Internal - DO NOT CALL THIS) Add cooldown to Cooldown Manager
	/// @param {String}		_name		Name of the Cooldown
	/// @param {Function}	_on_start	Function to execute on start	
	/// @param {Function}	_on_end		Function to execute on end
	/// @param {Real}		_duration	Cooldown Time in (_units)
	/// @param {Real}		_units		Unit of Time (seconds or frames)
	__add = function(_name, _on_start, _on_end, _duration, _units) 
	{
		var _start, _end, _cooldown;
		_cooldown = new CDC_Cooldown();
		
		_start = (is_undefined(_on_start) || !is_method(_on_start)) ? function () {} : _on_start;
		_end   = (is_undefined(_on_end) || !is_method(_on_end)) ? function () {} : _on_end;
		
		
		_cooldown.__on_start = method(self.__context, _start);
		_cooldown.__on_end = method(self.__context, _end);
		_cooldown.__name = _name;
		_cooldown.__units = _units;
		_cooldown.__duration = _duration;
		
		with _cooldown
		{
			__ts = time_source_create(CDC_TIME_SOURCE_DEFAULT, __duration, __units, function()
			{
				__on_end();	
				__state = CDC_STATE.READY;
			}
			);	
		}
		
		ds_map_add(self.__cooldowns, _name, _cooldown);
	}
	
	add = function(_name, _cooldown_struct)
	{
		var _on_start = undefined;
		var _on_end = undefined;
		
		var _duration, _units;
		var _properties = struct_get_names(_cooldown_struct);
		
		// Iterate and add custom function events
		for (var _i = 0; _i < array_length(_properties); _i++)
		{
			var _property_name = _properties[_i];
			var _property = struct_get(_cooldown_struct, _property_name);
			
			if (!is_method(_property)) continue;
			
			if (_property_name == "on_start") _on_start = _property;
			if (_property_name == "on_end") _on_end = _property;
		}
		
		_duration = (struct_exists(_cooldown_struct, "duration")) ? struct_get(_cooldown_struct, "duration") : 1;
		_units = (struct_exists(_cooldown_struct, "units")) ? struct_get(_cooldown_struct, "units") : CDC_DEFAULT_UNIT;
		
		__add(_name, _on_start, _on_end, _duration, _units);
	}
	
	/**
		@function			start(_name, _run_on_start)    Starts the cooldown specified by 'name'
		@param {String}		_name			Name of cooldown to start.	
		@param {Bool}		_run_on_start	Whether or not to execute the on_start function. Defaults to True.
	*/
	start = function (_name, _run_on_start = true) 
	{
		var _cooldown = get(_name);
		
		if (is_undefined(_cooldown))
		{
			show_debug_message($"CDC: Failed to Start {_name} doesn't exist");
			return false;
		}
		
		if (_cooldown.__state != CDC_STATE.READY)
		{
			show_debug_message($"CDC: Failed to Start {_name} is already running");
			return false;
		}
		
		if (_run_on_start) _cooldown.__on_start();
		
		_cooldown.__state = CDC_STATE.NOT_READY;
		time_source_start(_cooldown.__ts);
		return true;
	}
	
	/**
		@function			start_blocking(_name)    Sets the specified cooldown to the BLOCKING state
		@param {String}		_name			Name of cooldown to start blocking.	
	*/
	start_blocking = function (_name) 
	{
		var _cooldown = get(_name);
		
		if (is_undefined(_cooldown))
		{
			show_debug_message($"CDC: Failed to Start Blocking {_name} doesn't exist");
			return false;
		}
		
		if (_cooldown.__state != CDC_STATE.READY)
		{
			show_debug_message($"CDC: Failed to Start Blocking {_name} has already been started");
			return false;
		}
		
		_cooldown.__state = CDC_STATE.BLOCKING;
		return true;
	}
	
	/**
		@function			stop(_name)		 Stops the cooldown specified by 'name'
		@param {String}		_name			 Name of cooldown to stop.	
		@param {Bool}		_run_on_end	Whether or not to execute the on_end function. Defaults to True.
	*/
	stop = function (_name, _run_on_end = true) 
	{
		var _cooldown = get(_name);
		
		if (is_undefined(_cooldown))
		{
			show_debug_message($"CDC: Failed to Stop {_name} doesn't exist");
			return false;
		}
		
		if (_cooldown.__state != CDC_STATE.NOT_READY and _cooldown.__state != CDC_STATE.PAUSED)
		{
			show_debug_message($"CDC: Failed to Stop {_name} is not running");
			return false;
		}
		
		if (_cooldown.__state == CDC_STATE.PAUSED) resume(_name);
		
		if (_run_on_end) _cooldown.__on_end();
		
		_cooldown.__state = CDC_STATE.READY;
		time_source_stop(_cooldown.__ts);
		return true;
	}
	
	/**
		@function			pause(_name)	 Pauses the cooldown specified by 'name'
		@param {String}		_name			 Name of cooldown to pause.	
	*/
	pause = function (_name) 
	{
		var _cooldown = get(_name);
		
		if (is_undefined(_cooldown))
		{
			show_debug_message($"CDC: Failed to Pause {_name} doesn't exist");
			return false;
		}
		
		if (_cooldown.__state != CDC_STATE.NOT_READY)
		{
			show_debug_message($"CDC: Failed to Pause {_name} is not running");
			return false;
		}
		
		_cooldown.__state = CDC_STATE.PAUSED;
		time_source_pause(_cooldown.__ts);
		return true;
	}
	
	/**
		@function			resume(_name)	 Resumes the cooldown specified by 'name'
		@param {String}		_name			 Name of cooldown to resume.	
	*/
	resume = function (_name) 
	{
		var _cooldown = get(_name);
		
		if (is_undefined(_cooldown))
		{
			show_debug_message($"CDC: Failed to Resume {_name} doesn't exist");
			return false;
		}
		
		if (_cooldown.__state != CDC_STATE.PAUSED)
		{
			show_debug_message($"CDC: Failed to Resume {_name} is not paused");
			return false;
		}
		
		_cooldown.__state = CDC_STATE.NOT_READY;
		time_source_resume(_cooldown.__ts);
		return true;
	}
	
	/**
		@function			get(_name)      Returns the cooldown specified by 'name'
		@param {String}		_name			Name of cooldown to return.	
	*/
	get = function(_name)
	{
		var _cooldown = ds_map_find_value(__cooldowns, _name);
		if (!is_undefined(_cooldown)) return _cooldown;
		
		return undefined; 
	}

	/**
		@function			get_cooldown_remaining(_name)      Returns the remaining time for the specified cooldown
		@param {String}		_name							   Name of cooldown.	
	*/
	get_cooldown_remaining = function(_name)
	{
		var _cooldown = get(_name);
		if (!is_undefined(_cooldown)) return time_source_get_time_remaining(_cooldown.__ts);
		
		return undefined;
	}

	/**
		@function			get_cooldown_elapsed(_name)      Returns the elapsed time for the specified cooldown
		@param {String}		_name							 Name of cooldown.	
	*/
	get_cooldown_elapsed = function(_name)
	{
		var _cooldown = get(_name);
		if (!is_undefined(_cooldown)) return time_source_get_period(_cooldown.__ts) - time_source_get_time_remaining(_cooldown.__ts);
		
		return undefined;
	}
	
	/**
		@function			get_cooldown_percent(_name)      Returns the percentage of completion for the specified cooldown
		@param {String}		_name							 Name of cooldown.	
		@param {Real}		_scale							 OPTIONAL: The scale for the percentage to multipled with. Default 100.
	*/
	get_cooldown_percent = function(_name, _scale = 100)
	{
		var _cooldown = get(_name);
		if (is_undefined(_cooldown)) return undefined;	
		
		var _curr = time_source_get_time_remaining(_cooldown.__ts);
		var _total = time_source_get_period(_cooldown.__ts);
		
		return (1 - (_curr/_total)) * _scale;			
	}

	/**
		@function			get_cooldown_remaining(_name)      Returns the total duration for the specified cooldown
		@param {String}		_name							   Name of cooldown.	
	*/
	get_cooldown_duration = function(_name)
	{
		var _cooldown = get(_name);
		if (!is_undefined(_cooldown)) return time_source_get_period(_cooldown.__ts);
		
		return undefined;
	}
	
	/**
		@function			is_cooldown_ready(_name)		   Returns whether or not the cooldown is actively waiting to start (TRUE) or ticking down (FALSE)
		@param {String}		_name							   Name of cooldown.	
	*/
	is_cooldown_ready = function(_name)
	{
		var _cooldown = get(_name);
		if (!is_undefined(_cooldown)) return _cooldown.__state == CDC_STATE.READY;
		
		return undefined;
	}
	
	/**
		@function			is_cooldown_blocking(_name)		   Returns whether or not the cooldown is actively blocking
		@param {String}		_name							   Name of cooldown.	
	*/
	is_cooldown_blocking = function(_name)
	{
		var _cooldown = get(_name);
		if (!is_undefined(_cooldown)) return _cooldown.__state == CDC_STATE.BLOCKING;
		
		return undefined;
	}
	
	/**
		@function		destroy    Destroys the Cooldown Manager and all cooldowns
	*/
	destroy = function()
	{
		var _keys = [];
		_keys = ds_map_keys_to_array(self.__cooldowns);
		
		for(var _i = 0; _i < array_length(_keys); _i++)
		{
			var _key = _keys[_i];
			
			var _cooldown = ds_map_find_value(self.__cooldowns, _key);
			
			time_source_pause(_cooldown.__ts);
			time_source_destroy(_cooldown.__ts, true);
		}
		
		ds_map_destroy(__cooldowns);	
	}
	
	toString = function()
	{
		var _keys = [];
		_keys = ds_map_keys_to_array(self.__cooldowns);
		
		var _str = $"CDC Cooldown Manager: {instance_id_get(self.__context)}";
		for(var _i = 0; _i < array_length(_keys); _i++)
		{
			var _key = _keys[_i];
			
			var _cooldown = ds_map_find_value(self.__cooldowns, _key);
			_str += string($"{_cooldown}\n");
		}
		
		return _str;
	}
}

enum CDC_STATE
{
	NOT_READY,	// Cooldown is active and ticking down
	READY,		// Cooldown is not active
	PAUSED,		// Cooldown is active, but paused
	BLOCKING	// Cooldown is active, but timer is not started. Useful for disallowing an ability after cast but not starting the cooldown timer till the ability has finished (animating etc.).
}


