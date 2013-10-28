package com.inreflected.ui.touchscroll;

import haxe.Timer;
import flash.geom.Point;

/**
 * @author Pavel fljot
 */
class VelocityCalculator
{

	/**
	 *  @private
	 *  Weights to use when calculating velocity, giving the last velocity more of a weight 
	 *  than the previous ones.
	 */
	static var VELOCITY_WEIGHTS : Array<Float> = [1, 1.33, 1.66, 2, 2.33];

	/**
	 *  @private
	 *  Number of mouse movements to keep in the history to calculate 
	 *  velocity.
	 */
	static inline var HISTORY_LENGTH : Int = 5;
	/**
	 *  @private
	 *  Keeps track of the coordinates where the mouse events 
	 *  occurred.  We use this for velocity calculation along 
	 *  with timeHistory.
	 */
	var _coordinatesHistory : Array<Point>;
	/**
	 *  @private
	 *  Length of items in the mouseEventCoordinatesHistory and 
	 *  timeHistory Vectors since a circular buffer is used to 
	 *  conserve points.
	 */
	var _historyLength : Int;
	/**
	 *  @private
	 *  A history of times the last few mouse events occurred.
	 *  We keep HISTORY objects in memory, and we use this mouseEventTimeHistory
	 *  Vector along with mouseEventCoordinatesHistory to determine the velocity
	 *  a user was moving their fingers.
	 */
	var _timeHistory : Array<Int>;
	var _lastUpdateTime : Int;
	public function new()
	{
		_historyLength = 0;
		_coordinatesHistory = new Array<Point>();
		_timeHistory = new Array<Int>();
	}

	public function reset() : Void
	{
		// reset circular buffer index/length
		
		{
			_historyLength = 0;
			_lastUpdateTime = Std.int(Timer.stamp() * 1000);
		}

	}

	public function addOffsets(dx : Float, dy : Float, dt : Int = 0) : Point
	{
		// either use a Point object already created or use one already created
		// in mouseEventCoordinatesHistory
		{
			var currentPoint : Point;
			var currentIndex : Int = (_historyLength % HISTORY_LENGTH);
			if (_coordinatesHistory[currentIndex] != null)
			{
				currentPoint = _coordinatesHistory[currentIndex];
				currentPoint.x = dx;
				currentPoint.y = dy;
			}

			else 
			{
				currentPoint = new Point(dx, dy);
				_coordinatesHistory[currentIndex] = currentPoint;
			}

			// add time history as well
			var now : Int = Std.int(Timer.stamp() * 1000);
            _timeHistory[currentIndex] = dt != 0 ? dt : (now - _lastUpdateTime);
			_lastUpdateTime = now;
			//			CONFIG::Debug
			//			{
			//				trace("adding mouses event history:", dx, dy, _mouseEventTimeHistory[currentIndex]);
			//			}
			// increment current length if appropriate
			_historyLength++;
			return currentPoint;
		}
	}

	public function calculateVelocity(lastDt : Int = 0) : Point
	{
		if (lastDt == 0) 
		{
			lastDt = Std.int(Timer.stamp() * 1000) - _lastUpdateTime;
		}
		if (lastDt > 100) 
			// No movement for the past 100ms, so we treat it as a full stop.
		
		{
			return new Point(0, 0);
		}
;
		var len : Int = (_historyLength > (HISTORY_LENGTH) ? HISTORY_LENGTH : _historyLength);
		// if haven't wrapped around, then startIndex = 0.  If we've wrapped around,
		// then startIndex = mouseEventLength % EVENT_HISTORY_LENGTH.  The equation
		// below handles both of those cases
		var startIndex : Int = ((_historyLength - len) % HISTORY_LENGTH);
		// variables to store a running average
		var weightedSumX : Float = 0;
		var weightedSumY : Float = 0;
		var totalWeight : Float = 0;
		var currentIndex : Int = startIndex;
		var velocityWeight : Float;
		var currCoord : Point;
		var i : Int = 0;
		while(i < len)
		{
			currCoord = _coordinatesHistory[currentIndex];
			var dt : Int = _timeHistory[currentIndex];
			var dx : Float = currCoord.x;
			var dy : Float = currCoord.y;
			// TODO: фиксим "особенности платформы" (tm)?
			if (dt < 10) 
			{
				dt = 10;
			}
			// calculate a weighted sum for velocities
			velocityWeight = VELOCITY_WEIGHTS[i];
			weightedSumX += (dx / dt) * velocityWeight;
			weightedSumY += (dy / dt) * velocityWeight;
			totalWeight += velocityWeight;
			i++;
			currentIndex++;
			if (currentIndex >= HISTORY_LENGTH) 
				currentIndex = 0;
		}

		var vel : Point = new Point(0, 0);
		if (totalWeight > 0) 
		{
			vel.x = weightedSumX / totalWeight;
			vel.y = weightedSumY / totalWeight;
		}
				#if CONFIG_Debug

		{
			trace("calculateVelocity(): " + (vel));
		}
		#end // CONFIG_Debug

		return vel;
	}

}

