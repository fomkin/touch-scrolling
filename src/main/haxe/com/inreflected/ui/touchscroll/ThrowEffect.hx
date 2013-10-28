package com.inreflected.ui.touchscroll;

import haxe.Timer;
import com.inreflected.forks.spark.effects.animation.Keyframe;
import com.inreflected.forks.spark.effects.animation.MotionPath;
import com.inreflected.forks.spark.effects.easing.IEaser;
import com.inreflected.forks.spark.effects.easing.Power;
import flash.display.Shape;
import flash.events.Event;
import flash.geom.Point;
import com.inreflected.forks.spark.effects.animation.MotionPath;
import com.inreflected.forks.spark.effects.easing.EaseInOutBase;
import com.inreflected.forks.spark.effects.easing.IEaser;

/**
 * @author Pavel fljot
 */
class ThrowEffect
{
    public var duration(get_duration, never):Int;
    public var isPlaying(get_isPlaying, never):Bool;

    static var TICKER:Shape = new Shape();
    /**
	 *  @private
	 *  The duration of the settle effect when a throw "bounces" against the end of the list
	 *  or when we do snap effect (when throw velocity is zero).
	 */
    static inline var THROW_SETTLE_TIME:Int = 600;
    /**
	 *  @private
	 */
    static inline var SETTLE_THROW_VELOCITY:Float = 5;
    /**
	 *  @private
	 *  The velocity at which we treat throw motion as finished.
	 *  1 px/frame = framerate/1000 px/ms
	 */
    static inline var STOP_VELOCITY:Float = 0.02;
    // px per ms
    /**
	 *  @private
	 *  The initial velocity of the throw animation.
	 */
    public var startingVelocityX:Float;
    public var startingVelocityY:Float;
    /**
	 *  @private
	 *  The starting values for the animated properties.
	 */
    public var startingPositionX:Float;
    public var startingPositionY:Float;
    /**
	 *  @private
	 *  The minimum values for the animated properties.
	 */
    public var minPositionX:Float;
    public var minPositionY:Float;
    /**
	 *  @private
	 *  The maximum values for the animated properties.
	 */
    public var maxPositionX:Float;
    public var maxPositionY:Float;
    /**
	 *  @private
	 *  The rate of deceleration to apply to the velocity.
	 */
    public var decelerationRate:Float;
    public var pull:Bool;
    public var bounce:Bool;
    public var maxBounce:Float;
    public var viewportWidth:Float;
    public var viewportHeight:Float;
    /**
	 *  @private
	 *  The final calculated values for the animated properties.
	 */
    public var finalPosition:Point;
    /**
	 *  @private
	 *  This is a callback that, when installed by the client, will be invoked
	 *  with the final position of the throw in case the client needs to alter it
	 *  prior to the animation beginning.
	 */
    public var finalPositionFilterFunction:Float -> String -> Float;
    public var onUpdateCallback:Float -> Float -> Void;
    public var onCompleteCallback:Void -> Void;
    /**
	 *  @private
	 *  Set to true when the effect is only being used to snap an element into position
	 *  and the initial velocity is zero.
	 */
    public var isSnapping:Bool;
    /**
	 *  @private
	 *  The motion paths for X and Y axes
	 */
    var horizontalMP:MotionPath;
    var verticalMP:MotionPath;
    var _effectFollower:PathsFollower;
    var _effectStartTime:Int;
    var _effectTarget:ScrollableObjectModel;

    public function new()
    {
        startingVelocityX = 0;
        startingVelocityY = 0;
        startingPositionX = 0;
        startingPositionY = 0;
        minPositionX = 0;
        minPositionY = 0;
        maxPositionX = 0;
        maxPositionY = 0;
        isSnapping = false;
        horizontalMP = null;
        verticalMP = null;
        _effectFollower = new PathsFollower();
        _effectTarget = new ScrollableObjectModel();
        _effectFollower.target = _effectTarget;
    }

    /** @private */
    var _duration:Int;
    /**
	 *
	 */

    public function get_duration():Int
    {
        return _duration;
    }

    /** @private */
    var _isPlaying:Bool;
    /**
	 *
	 */

    public function get_isPlaying():Bool
    {
        return _isPlaying;
    }

    //--------------------------------------------------------------------------
    //
    //  Public methods
    //
    //--------------------------------------------------------------------------

    public function play():Void
    {
        if (!isPlaying)
        {
            _isPlaying = true;
            _effectStartTime = Std.int(Timer.stamp() * 1000);
            TICKER.addEventListener(Event.ENTER_FRAME, target_enterFrameHandler);
        }
    }

    /**
	 *  @private
	 *  Once all the animation variables are set (velocity, position, etc.), call this
	 *  function to build the motion paths that describe the throw animation.
	 */

    public function setup():Bool
    {
        var throwEffectMotionPaths:Array<MotionPath> = new Array<MotionPath>();
        isSnapping = false;
        _effectTarget.positionX = startingPositionX;
        _effectTarget.positionY = startingPositionY;
        var lastKeyFrameIndex:Int;
        var horizontalTime:Float = 0;
        var finalHSP:Float = startingPositionX;
        horizontalMP = createThrowMotionPath("positionX", startingVelocityX, startingPositionX, minPositionX, maxPositionX, viewportWidth);
        if (horizontalMP != null)
        {
            throwEffectMotionPaths.push(horizontalMP);
            lastKeyFrameIndex = horizontalMP.keyframes.length - 1;
            horizontalTime = horizontalMP.keyframes[lastKeyFrameIndex].time;
            finalHSP = horizontalMP.keyframes[lastKeyFrameIndex].value;
        }
        var verticalTime:Float = 0;
        var finalVSP:Float = startingPositionY;
        verticalMP = null;
        verticalMP = createThrowMotionPath("positionY", startingVelocityY, startingPositionY, minPositionY, maxPositionY, viewportHeight);
        if (verticalMP != null)
        {
            throwEffectMotionPaths.push(verticalMP);
            lastKeyFrameIndex = verticalMP.keyframes.length - 1;
            verticalTime = verticalMP.keyframes[lastKeyFrameIndex].time;
            finalVSP = verticalMP.keyframes[lastKeyFrameIndex].value;
        }
        if (horizontalMP != null || verticalMP != null)
            // Fix motion paths to have visually independent durations for axis tweens
        {
            if (horizontalMP != null && verticalMP != null)
            {
                if (horizontalTime < verticalTime)
                {
                    addKeyframe(horizontalMP, verticalTime, finalHSP, new Power());
                }

                else if (verticalTime < horizontalTime)
                {
                    addKeyframe(verticalMP, horizontalTime, finalVSP, new Power());
                }
            }
            _duration = Std.int(Math.max(horizontalTime, verticalTime));
            _effectFollower.motionPaths = throwEffectMotionPaths;
            _effectFollower.progress = 0;
            finalPosition = new Point(finalHSP, finalVSP);
            return true;
        }
        ;
        return false;
    }

    public function stop(notifyComplete:Bool = true):Void
    {
        if (_isPlaying)
        {
            TICKER.removeEventListener(Event.ENTER_FRAME, target_enterFrameHandler);
            _isPlaying = false;
            if (notifyComplete)
            {
                onCompleteCallback();
            }
        }
    }

    /**
	 *  @private
	 *  Calculates the current velocities of the in-progress throw animation
	 */

    public function getCurrentVelocity():Point
    {
        var effectDuration:Float = this.duration;
        // Get the current position of the existing throw animation
        var effectTime:Float = _effectFollower.progress * effectDuration;
        var velX:Float = (horizontalMP != null) ? getMotionPathCurrentVelocity(horizontalMP, effectTime, effectDuration) : 0;
        var velY:Float = (verticalMP != null) ? getMotionPathCurrentVelocity(verticalMP, effectTime, effectDuration) : 0;
        return new Point(velX, velY);
    }

    //--------------------------------------------------------------------------
    //
    //  Private methods
    //
    //--------------------------------------------------------------------------
    /**
	 *  @private
	 */

    function calculateThrowEffectTime(velocity:Float, decelerationRate:Float):Int
    {
        // This calculates the effect duration based on a deceleration factor that is applied evenly over time.
        // We decay the velocity by the deceleration factor until it is less than STOP_VELOCIY px/ms,
        // which is rounded to zero pixels.
        // The exponential decay formula for the velocity is:
        // V(t) = V0 * d^t, where:
        // V0 is initial velocity;
        // d is decelerationRate, a value a bit less then 1.
        // We want to solve for "t" in this equasion: V0*d^t - Vstop = 0.
        // d^T = Vstop/V0
        // t/effect duration/ = T = log(Vstop/V0) / log(d)
        // The actual position formula is integral of V(t):
        // S(t) = V0/log(d) * d^t + C, where C is some constant.
        // S(t=0) must be 0, so C = -V0/log(d) and so position formula is:
        // S(t) = V0/log(d) * (d^t - 1)
        // so final position is S(t=T) = (Vstop - V0) / log(d)
        // The condition has pure mathematical purpose: not to have negative time.

        {
            var absVelocity:Float = velocity > (0) ? velocity : -velocity;
            var time:Int = Std.int(absVelocity <= (STOP_VELOCITY) ? 0 : Math.log(STOP_VELOCITY / absVelocity) / Math.log(decelerationRate));
            return time;
        }

    }

    /**
	 *  @private
	 *  A utility function to add a new keyframe to the motion path and return the frame time.
	 */

    function addKeyframe(motionPath:MotionPath, time:Float, position:Float, easer:IEaser):Float
    {
        var keyframe:Keyframe = new Keyframe(time, position);
        keyframe.easer = easer;
        motionPath.keyframes.push(keyframe);
        return time;
    }

    /**
	 *  @private
	 *  This function builds a motion path that reflects the starting conditions (position, velocity)
	 *  and exhibits overshoot/settle/snap effects (aka bounce/pull) according to the min/max boundaries.
	 */

    function createThrowMotionPath(propertyName:String, velocity:Float, position:Float, minPosition:Float, maxPosition:Float, viewportSize:Float):MotionPath
    {
        var motionPath:MotionPath = new MotionPath(propertyName);
        var nowTime:Float = 0;
        var effectTime:Float = Math.NaN;
        var alignedPosition:Float = Math.NaN;
        var decelerationRate:Float = this.decelerationRate;

        motionPath.keyframes = [ new Keyframe(0, position) ];

        // First, we handle the case where the velocity is zero (finger wasn't significantly moving when lifted).
        // Ordinarily, we do nothing in this case, but if the list is currently scrolled past its end (i.e. "pulled"),
        // we need to have the animation move it back so none of the empty space is visible.
        if (velocity == 0)
        {
            // Velocity is zero and we're past the end of the list.  We want the
            // list to "snap" back to its resting position at the end.  We use a
            // cubic easer curve so the snap has high initial velocity and
            // gradually decelerates toward the resting point.
            if (position < minPosition || position > maxPosition)
            {
                position = position < (minPosition) ? minPosition : maxPosition;
                if (finalPositionFilterFunction != null)
                {
                    position = finalPositionFilterFunction(position, propertyName);
                }
                //FIXME: why not alignedPosition and isSnapping = true?
                nowTime = addKeyframe(motionPath, nowTime + THROW_SETTLE_TIME, position, new Expo(SETTLE_THROW_VELOCITY, STOP_VELOCITY));
            }
            else
            {
                // See if we need to snap into alignment
                alignedPosition = position;
                if (finalPositionFilterFunction != null)
                {
                    alignedPosition = finalPositionFilterFunction(position, propertyName);
                }
                if (alignedPosition == position)
                    return null;
                isSnapping = true;
                nowTime = addKeyframe(motionPath, nowTime + THROW_SETTLE_TIME, alignedPosition, new Expo(SETTLE_THROW_VELOCITY, STOP_VELOCITY));
            }

        }
        // Each iteration of this loop adds one of more keyframes to the motion path and then
        // updates the velocity and position values.  Once the velocity has decayed to zero,
        // the motion path is complete.
        while (velocity != 0.0)
        {
            if ((position <= minPosition && velocity > 0) || (position >= maxPosition && velocity < 0))
                // We're past the end of the list
                // <upd>OR exatly at the edge (in order to unclide maxPull logic)</upd>
                // and the velocity is directed further beyond
                // the end. In this case we want to overshoot the end of the list and then
                // settle back to it.
                // The throw is STARTED beyond the end / on the edge
            {
                var throwJustStartedBeyondBounds:Bool = (effectTime != effectTime);
                //faster isNaN
                if (throwJustStartedBeyondBounds)
                {
                    if (!pull && (position == minPosition || position == maxPosition))
                        // no throw applied
                    {
                        return null;
                    }
                    ;
                    // so we want to minimize overshoot and effect time (but not totally)
                    // to have something more close to regular settle effect.
                    decelerationRate *= 0.9;
                }
                if (bounce || throwJustStartedBeyondBounds)
                {
                    var settlePosition:Float = position < (minPosition) ? minPosition : maxPosition;
                    if (finalPositionFilterFunction != null)
                    {
                        settlePosition = finalPositionFilterFunction(settlePosition, propertyName);
                    }
                    if (!throwJustStartedBeyondBounds)
                        // Reduce decelerationFactor as velocity increases (to make overshoot
                        // visually relatively equal and quick).
                    {
                        decelerationRate *= 0.98 * Math.pow(0.998, velocity > (0) ? velocity : -velocity);
                    }
                    ;
                    var overshootTime:Int = calculateThrowEffectTime(velocity, decelerationRate);
                    var overshootPosition:Float = Math.round(position + (velocity - STOP_VELOCITY) / Math.log(decelerationRate));
                    if (!throwJustStartedBeyondBounds)
                        // We want to limit overshootPosition only for the bounce, not "pull&throw"
                    {
                        var maxOvershootDistance:Float = maxBounce * viewportSize;
                        var adjustedOvershootPosition:Float = Math.min(Math.max(minPosition - maxOvershootDistance, overshootPosition), maxPosition + maxOvershootDistance);
                        if (adjustedOvershootPosition != overshootPosition)
                        {
                            overshootPosition = adjustedOvershootPosition;
                            // Adjust decelerationFactor & time to keep motion curve correct
                            // (given current velocity and desired overshoot)
                            decelerationRate = Math.exp((STOP_VELOCITY - Math.abs(velocity)) / maxOvershootDistance);
                            overshootTime = calculateThrowEffectTime(velocity, decelerationRate);
                        }
                    }
                    ;
                    nowTime = addKeyframe(motionPath, nowTime + overshootTime, overshootPosition, new Expo(velocity, STOP_VELOCITY));
                    nowTime = addKeyframe(motionPath, nowTime + THROW_SETTLE_TIME, settlePosition, new Expo(SETTLE_THROW_VELOCITY, STOP_VELOCITY));
                }
                // Clear the velocity to indicate that the motion path is complete.
                velocity = 0;
            }

            else // Here we're going to do a "normal" throw.
            {
                effectTime = calculateThrowEffectTime(velocity, decelerationRate);
                var finalPosition:Float = Math.round(position + (velocity - STOP_VELOCITY) / Math.log(decelerationRate));
                #if CONFIG_Debug

				{
					trace("finalPosition args:", position, velocity, finalPosition);
				}
				#end // CONFIG_Debug

                // The throw is starting beyond the edge of the list and the velocity
                // is not high enough (so blank area would be exposed after throw).
                // Treat it as zero velocity to have regular snapping effect.
                if ((position < minPosition && finalPosition < minPosition) || (position > maxPosition && finalPosition > maxPosition))
                {
                    velocity = 0;
                    return createThrowMotionPath(propertyName, velocity, position, minPosition, maxPosition, viewportSize);
                }
                ;
                if (finalPosition < minPosition || finalPosition > maxPosition)
                    // The throw is going to hit the end of the list.  In this case we need to clip the
                    // deceleration curve at the appropriate point.  We want the curve to look exactly as
                    // it would if we were allowing the throw to go beyond the end of the list.  But the
                    // keyframe we add here will stop exactly at the end.  The subsequent loop iteration
                    // will add keyframes that describe the overshoot & settle behavior.
                {
                    var edgePosition:Float = finalPosition < (minPosition) ? minPosition : maxPosition;
                    //TODO: explanation comment
                    var partialTime:Float = Math.log((velocity + Math.log(decelerationRate) * (position - edgePosition)) / velocity) / Math.log(decelerationRate);
                    if (partialTime != partialTime)
                        //isNaN
                    {
                        throw "partialTime != partialTime";
                    }
                    ;
                    // PartialExpo creates a portion of the throw easer curve, but scaled up to fill the
                    // specified duration.
                    nowTime = addKeyframe(motionPath, nowTime + partialTime, edgePosition, new PartialExpo(velocity, STOP_VELOCITY, partialTime / effectTime));
                    // Set the position just past the end of the list for the next loop iteration.
                    if (finalPosition < minPosition)
                        position = minPosition - 1;
                    if (finalPosition > maxPosition)
                        position = maxPosition + 1;
                    // Set the velocity for the next loop iteration.  Make sure it matches the actual velocity in effect when the
                    // throw reaches the end of the list.
                    velocity = velocity * Math.pow(decelerationRate, partialTime);
                }

                else // This is the simplest case.  The throw both begins and ends on the list (i.e. not past the
                    // end of the list).  We create a single keyframe and clear the velocity to indicate that the
                    // motion path is complete.
                {
                    if (Math.isNaN(finalPosition))
                        // temporary for debug reasons. I experienced NaN once
                    {
                        throw "finalPosition is NaN";
                    }
                    ;
                    if (finalPositionFilterFunction != null)
                    {
                        finalPosition = finalPositionFilterFunction(finalPosition, propertyName);
                    }
                    nowTime = addKeyframe(motionPath, nowTime + effectTime, finalPosition, new Expo(velocity, STOP_VELOCITY));
                    velocity = 0;
                }

            }

        }

        return motionPath;
    }

    /**
	 *  @private
	 *  Helper function for getCurrentVelocity.
	 */

    function getMotionPathCurrentVelocity(mp:MotionPath, currentTime:Float, totalTime:Float):Float
    {
        // Determine the fraction of the effect that has already played.

        {
            var fraction:Float = currentTime / totalTime;
            // Now we need to determine the effective velocity at the effect's current position.
            // Here we use a "poor man's" approximation that doesn't require us to know any of the
            // derivative functions associated with the motion path.  We sample the position at two
            // time values very close together and assume the velocity slope is a straight line
            // between them.  The smaller the distance between the two time values, the closer the
            // result will be to the "instantaneous" velocity.
            var TINY_DELTA_TIME:Float = 0.00001;
            var value1:Float = mp.getValue(fraction);
            var value2:Float = mp.getValue(fraction + (TINY_DELTA_TIME / totalTime));
            return (value2 - value1) / TINY_DELTA_TIME;
        }

    }

    function target_enterFrameHandler(event:Event):Void
    {
        var progress:Float = (Std.int(Timer.stamp() * 1000) - _effectStartTime) / _duration;
        if (progress > 1)
        {
            progress = 1;
        }
        _effectFollower.progress = progress;
        onUpdateCallback(_effectTarget.positionX, _effectTarget.positionY);
        if (progress == 1)
        {
            stop();
        }
    }

}

class Expo implements IEaser
{

    var k1:Float;
    var k2:Float;

    public function new(v0:Float, vStop:Float = 0.01)
    {
        v0 = v0 < (0) ? -v0 : v0;
        k1 = vStop / v0;
        k2 = 1 / (k1 - 1);
    }

    public function ease(fraction:Float):Float
    {
        return k2 * (Math.pow(k1, fraction) - 1);
    }

}

class ScrollableObjectModel
{

    public var positionX:Float;
    public var positionY:Float;

    public function new()
    {
    }
}

/**
 *  @private
 *  A custom ease-out-only easer class which animates along a specified
 *  portion of an exponential curve.
 */
class PartialExpo extends Expo
{

    var _xscale:Float;
    var _ymult:Float;

    public function new(v0:Float, vStop:Float, xscale:Float)
    {
        super(v0, vStop);
        _xscale = xscale;
        _ymult = 1 / super.ease(_xscale);
    }

    override public function ease(fraction:Float):Float
    {
        return _ymult * super.ease(fraction * _xscale);
    }

}

/**
 *  @private
 *  A custom ease-out-only easer class which animates along a specified
 *  portion of an exponential curve.
 */
class PartialExponentialCurve extends EaseInOutBase
{

    var _xscale:Float;
    var _ymult:Float;
    var _exponent:Float;

    public function new(exponent:Float, xscale:Float)
    {
        super(0);
        _exponent = exponent;
        _xscale = xscale;
        _ymult = 1 / (1 - Math.pow(1 - _xscale, _exponent));
    }

    override function easeOut(fraction:Float):Float
    {
        return _ymult * (1 - Math.pow(1 - fraction * _xscale, _exponent));
    }

}

/**
 * @author Pavel fljot
 */
class PathsFollower
{
    public var rawProgress(get_rawProgress, set_rawProgress):Float;
    public var progress(get_progress, set_progress):Float;

    public var target:Dynamic;
    public var cachedProgress:Float;
    public var cachedRawProgress:Float;

    public function new(target:Dynamic = null)
    {
        this.target = target;
        this.cachedProgress = this.cachedRawProgress = 0;
    }

    public var motionPaths:Array<MotionPath>;
    /**
	 * Identical to <code>progress</code> except that the value doesn't get re-interpolated between 0 and 1.
	 * <code>rawProgress</code> (and <code>progress</code>) indicates the follower's position along the motion path.
	 * For example, to place the object on the path at the halfway point, you could set its <code>rawProgress</code>
	 * to 0.5. You can tween to values that are greater than 1 or less than 0. For example, setting <code>rawProgress</code>
	 * to 1.2 also sets <code>progress</code> to 0.2 and setting <code>rawProgress</code> to -0.2 is the
	 * same as setting <code>progress</code> to 0.8. If your goal is to tween the PathFollower around a Circle2D twice
	 * completely, you could just add 2 to the <code>rawProgress</code> value or use a relative value in the tween, like: <br /><br /><code>
	 *
	 * TweenLite.to(myFollower, 5, {rawProgress:"2"}); // or myFollower.rawProgress + 2
	 *
	 * </code><br /><br />
	 *
	 * Since <code>rawProgress<code> doesn't re-interpolate values to always fitting between 0 and 1, it
	 * can be useful if you need to find out how many times the PathFollower has wrapped.
	 *
	 * @see #progress
	 **/

    public function get_rawProgress():Float
    {
        return this.cachedRawProgress;
    }

    public function set_rawProgress(value:Float):Float
    {
        this.progress = value;
        return value;
    }

    /**
	 * A value between 0 and 1 that indicates the follower's position along the motion path. For example,
	 * to place the object on the path at the halfway point, you would set its <code>progress</code> to 0.5.
	 * You can tween to values that are greater than 1 or less than 0 but the values are simply wrapped.
	 * So, for example, setting <code>progress</code> to 1.2 is the same as setting it to 0.2 and -0.2 is the
	 * same as 0.8. If your goal is to tween the PathFollower around a Circle2D twice completely, you could just
	 * add 2 to the <code>progress</code> value or use a relative value in the tween, like: <br /><br /><code>
	 *
	 * TweenLite.to(myFollower, 5, {progress:"2"}); // or myFollower.progress + 2
	 *
	 * </code><br /><br />
	 *
	 * <code>progress</code> is identical to <code>rawProgress</code> except that <code>rawProgress</code>
	 * does not get re-interpolated between 0 and 1. For example, if <code>rawProgress</code>
	 * is set to -3.4, <code>progress</code> would be 0.6. <code>rawProgress<code> can be useful if
	 * you need to find out how many times the PathFollower has wrapped.
	 *
	 * @see #rawProgress
	 **/

    public function get_progress():Float
    {
        return this.cachedProgress;
    }

    public function set_progress(value:Float):Float
    {
        if (value > 1)
        {
            this.cachedRawProgress = value;
            this.cachedProgress = value - Std.int(value);
            if (this.cachedProgress == 0)
            {
                this.cachedProgress = 1;
            }
        }

        else if (value < 0)
        {
            this.cachedRawProgress = value;
            this.cachedProgress = value - (Std.int(value) - 1);
        }

        else
        {
            this.cachedRawProgress = Std.int(this.cachedRawProgress) + value;
            this.cachedProgress = value;
        }

        for (path in motionPaths/* AS3HX WARNING could not determine type for var: path exp: EIdent(motionPaths) type: Array<MotionPath>*/
        )
        {
            Reflect.setField(target, path.property, path.getValue(cachedProgress));
        }

        return value;
    }

}

