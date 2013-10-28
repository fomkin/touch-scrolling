////////////////////////////////////////////////////////////////////////////////
//
//  Licensed to the Apache Software Foundation (ASF) under one or more
//  contributor license agreements.  See the NOTICE file distributed with
//  this work for additional information regarding copyright ownership.
//  The ASF licenses this file to You under the Apache License, Version 2.0
//  (the "License"); you may not use this file except in compliance with
//  the License.  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
////////////////////////////////////////////////////////////////////////////////
package com.inreflected.forks.spark.effects.easing;

/**
 *  The Linear class defines an easing with three phases:
 *  acceleration, uniform motion, and deceleration.
 *  As the animation starts it accelerates through the period
 *  specified by the <code>easeInFraction</code> property, it
 *  then uses uniform (linear) motion through the next phase, and
 *  finally decelerates until the end during the period specified
 *  by the <code>easeOutFraction</code> property.
 *
 *  <p>The easing values for the three phases are calculated
 *  such that the behavior of constant acceleration, linear motion,
 *  and constant deceleration all occur within the specified
 *  duration of the animation.</p>
 *
 *  <p>Strict linear motion can be achieved by setting
 *  <code>easeInFraction</code> and <code>easeOutFraction</code> to 0.0.
 *  Note that if acceleration or
 *  deceleration are not 0.0, then the motion during the middle
 *  phase is not at the same speed as that of pure
 *  linear motion. The middle phase consists of
 *  uniform motion, but the speed of that motion is determined by
 *  the size of that phase relative to the overall animation.</p>
 *
 *  @mxml
 *
 *  <p>The <code>&lt;s:Linear&gt;</code> tag
 *  inherits all of the tag attributes of its of its superclass,
 *  and adds the following tag attributes:</p>
 *
 *  <pre>
 *  &lt;s:Linear
 *    id="ID"
 *    easeInFraction="0"
 *    easeOutFraction="0"
 *   /&gt;
 *  </pre>
 *
 *  @includeExample examples/LinearEffectExample.mxml
 *
 *  @langversion 3.0
 *  @playerversion Flash 10
 *  @playerversion AIR 1.5
 *  @productversion Flex 4
 */
class Linear implements IEaser
{
	public var easeInFraction(get_easeInFraction, set_easeInFraction) : Float;
	public var easeOutFraction(get_easeOutFraction, set_easeOutFraction) : Float;

	/**
     *  Constructor.
     *
     *  @param easeInFraction The fraction of the overall duration
     *  in the acceleration phase, between 0.0 and 1.0.
     *
     *  @param easeOutFraction The fraction of the overall duration
     *  in the deceleration phase, between 0.0 and 1.0.
     *
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
	public function new(easeInFraction : Float = 0, easeOutFraction : Float = 0)
	{
		this.easeInFraction = easeInFraction;
		this.easeOutFraction = easeOutFraction;
	}

	/**
     * Storage for the _easeInFraction property
     *
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
	var _easeInFraction : Float;
	/**
     *  The fraction an animation spent accelerating,
     *  between 0.0 and 1.0.
     *  The values of the <code>easeOutFraction</code> property
     *  and <code>easeInFraction</code> property must satisfy the
     *  equation <code>easeOutFraction + easeInFraction &lt;= 1</code>
     *  where any remaining time is spent in the linear motion phase.
     *
     *  @default 0
     *
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
	public function get_easeInFraction() : Float
	{
		return _easeInFraction;
	}

	public function set_easeInFraction(value : Float) : Float
	{
		_easeInFraction = value;
		return value;
	}

	/**
     * Storage for the _easeInFraction property
     *
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
	var _easeOutFraction : Float;
	/**
     *  The percentage an animation will spend decelerating,
     *  between 0.0 and 1.0.
     *  The values of the <code>easeOutFraction</code> property
     *  and <code>easeInFraction</code> property must satisfy the
     *  equation <code>easeOutFraction + easeInFraction &lt;= 1</code>
     *  where any remaining time is spent in the linear motion phase.
     *
     *  @default 0
     *
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
	public function get_easeOutFraction() : Float
	{
		return _easeOutFraction;
	}

	public function set_easeOutFraction(value : Float) : Float
	{
		_easeOutFraction = value;
		return value;
	}

	/**
     *  Calculates the eased fraction value based on the
     *  <code>easeInFraction</code> and <code>easeOutFraction</code>
     *  properties.
     *  If <code>fraction</code>
     *  is less than <code>easeInFraction</code>, it calculates a value
     *  based on accelerating up to the linear motion phase.
     *  If <code>fraction</code>
     *  is greater than <code>easeInFraction</code> and less than
     *  <code>(1-easeOutFraction)</code>, it calculates a value based
     *  on the linear motion phase between the easing in and easing out phases.
     *  Otherwise, it calculates a value based on constant deceleration
     *  between the linear motion phase and 0.0.
     *
     *  @param fraction The elapsed fraction of the animation,
     *  between 0.0 and 1.0..
     *
     *  @return The eased fraction of the animation.
     *
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
	public function ease(fraction : Float) : Float
	{
		// Handle the trivial case where no easing is requested
		
		{
			if (easeInFraction == 0 && easeOutFraction == 0) 
				return fraction;
			var runRate : Float = 1 / (1 - (easeInFraction + easeOutFraction) * 0.5);
			if (fraction < easeInFraction) 
				return fraction * runRate * (fraction / easeInFraction) * 0.5;
			if (fraction > (1 - easeOutFraction)) 
			{
				var decTime : Float = fraction - (1 - easeOutFraction);
				var decProportion : Float = decTime / easeOutFraction;
				return runRate * (1 - (easeInFraction - decTime * (2 - decProportion)) * 0.5 - easeOutFraction);
			}
			return runRate * (fraction - easeInFraction * 0.5);
		}

	}

}

