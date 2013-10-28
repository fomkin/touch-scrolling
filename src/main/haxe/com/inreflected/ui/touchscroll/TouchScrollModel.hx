package com.inreflected.ui.touchscroll;

import flash.events.TimerEvent;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.system.Capabilities;
import flash.utils.Timer;

/**
 * @author Pavel fljot
 */
class TouchScrollModel
{
    public var scrollBounds(get_scrollBounds, set_scrollBounds):Rectangle;
    public var contentWidth(get_contentWidth, null):Float;
    public var contentHeight(get_contentHeight, null):Float;
    public var canScrollHorizontally(get_canScrollHorizontally, null):Bool;
    public var canScrollVertically(get_canScrollVertically, null):Bool;
    public var inTouchInteraction(get_inTouchInteraction, null):Bool;
    public var isScrolling(get_isScrolling, null):Bool;
    public var pagingEnabled(get_pagingEnabled, set_pagingEnabled):Bool;

    /**
	 * @private
	 * Default value of maxPull.
	 */
    static public inline var MAX_PULL_FACTOR:Float = 0.4;

    /**
	 * @private
	 * Default value of maxBounce.
	 */
    static public inline var MAX_OVERSHOOT_FACTOR:Float = 0.4;

    /**
	 * Factor for pull curve.
	 */
    static inline var PULL_TENSION_FACTOR:Float = 1.5;

    /**
	 *  @private
	 *  Minimum velocity needed to start a throw effect, in pixels per millisecond.
	 */
    static var MIN_START_VELOCITY:Float = 0.6 * Capabilities.screenDPI / 1000;

    /**
	 * based on 20 pixels on a 252ppi device.
	 */
    static var DIRECTIONAL_LOCK_THRESHOLD_DISTANCE:Float = Math.round(20 / 252 * Capabilities.screenDPI);
    static var DIRECTIONAL_LOCK_THRESHOLD_ANGLE:Float = 20 * Math.PI / 180;

    public var positionUpdateCallback:Float -> Float -> Void;
    public var throwCompleteCallback:Void -> Void;

    /**
	 * Whether to bounce/pull at the edges or not.
	 * 
	 * @default true
	 */
    public var bounceEnabled:Bool;
    public var allwaysBounceHorizontal:Bool;
    public var allwaysBounceVertical:Bool;

    /**
	 *  The amount of deceleration to apply to the velocity for each throw effect period.
	 *  For a faster deceleration, you can switch this to TouchScrollDecelerationRate.FAST
	 *  (which is equal to 0.990).
	 */
    public var decelerationRate:Float;

    /**
	 * A flag that determines whether scrolling is disabled in a particular direction.
	 * 
	 * <p>If this property is <code>false</code>(the default), scrolling is permitted
	 * in both horizontal and vertical directions. If this property is <code>true</code>
	 * and the user begins dragging in one general direction (horizontally or vertically),
	 * this manager disables scrolling in the other direction.
	 * If the drag direction is diagonal, then scrolling will not be locked and the user
	 * can drag in any direction until the drag completes.</p>
	 * 
	 * @default false
	 */
    public var directionalLock:Bool;
    public var directionalLockThresholdDistance:Float;
    public var directionalLockThresholdAngle:Float;

    /**
	 * Minimum velocity needed to start a throw effect, in pixels per millisecond.
	 * 
	 * @default 0.6 inches/s
	 */
    public var minVelocity:Float;

    /**
	 * Maximum velocity for a throw effect. Not limited by default.
	 */
    public var maxVelocity:Float;

    /**
	 * A way to control pull tention/distance. Should be value between 0 and 1.
	 * Setting this property to NaN produces default pull
	 * with maximum value of 0.4 (40% of viewport size).
	 */
    public var maxPull:Float;

    /**
	 * A way to limit bounce tention/distance.
	 * Setting this property to NaN produces default bounce
	 * with maximum value of 0.4 (40% of viewport size).
	 */
    public var maxBounce:Float;
    var _viewportWidth:Float;
    var _viewportHeight:Float;
    var _positionX:Float;
    var _positionY:Float;

    /**
	 *  Keeps track of the horizontal scroll position
	 *  before scrolling started, used to perform drag scroll.
	 */
    var _touchHSP:Float;

    /**
	 *  Keeps track of the vertical scroll position
	 *  before scrolling started, used to perform drag scroll.
	 */
    var _touchVSP:Float;
    var _lastDirectionX:Int;
    var _lastDirectionY:Int;
    var _cummulativeOffsetX:Float;
    var _cummulativeOffsetY:Float;
    var _directionalLockTimer:Timer;
    var _directionalLockThresholdAngleCoefficient:Float;
    var _directionalLockCummulativeOffsetX:Float;
    var _directionalLockCummulativeOffsetY:Float;
    var _directionLockTimerStartPoint:Point;
    var _velocityCalculator:VelocityCalculator;
    var _throwEffect:ThrowEffect;

    /**
	 *  @private
	 *  The final position in the throw effect's horizontal motion path
	 */
    var _throwFinalHSP:Float;
    var _throwFinalVSP:Float;
    var _currentPageHSP:Float;
    var _currentPageVSP:Float;
    //----------------------------------
    // Flags
    //----------------------------------
    var _lockHorizontal:Bool;
    var _lockVertical:Bool;
    var _throwReachedEdgePosition:Bool;

    public function new()
    {
        bounceEnabled = true;
        allwaysBounceHorizontal = true;
        allwaysBounceVertical = true;
        maxPull = MAX_PULL_FACTOR;
        decelerationRate = TouchScrollDecelerationRate.NORMAL;
        directionalLockThresholdDistance = DIRECTIONAL_LOCK_THRESHOLD_DISTANCE;
        directionalLockThresholdAngle = DIRECTIONAL_LOCK_THRESHOLD_ANGLE;
        minVelocity = 0;
        _viewportWidth = 0;
        _viewportHeight = 0;
        _positionX = 0;
        _positionY = 0;
        _directionalLockTimer = new Timer(600, 1);
        _directionalLockCummulativeOffsetX = 0;
        _directionalLockCummulativeOffsetY = 0;
        _velocityCalculator = new VelocityCalculator();
        _currentPageHSP = 0;
        _currentPageVSP = 0;
        _scrollBounds = new Rectangle();
        _measuredScrollBounds = new Rectangle();
        _contentWidth = 0;
        _contentHeight = 0;
        _directionalLockTimer.addEventListener(TimerEvent.TIMER, directionalLockTimer_timerHandler);
    }

    /** @private */
    var _scrollBounds:Rectangle;
    var _measuredScrollBounds:Rectangle;
    var _explicitScrollBounds:Rectangle;

    /**
	 * Scroll bounds may change for 2 reasons:
	 * 1. Device orientation changing leading to viewport size change and 
	 * 2. Other layout changes.
	 * 
	 * If device orientation is changing it is recommended to simply stop throw effect
	 * (if playing) and snap positions to valid values (because it is hard to guess correctly
	 * for any more complicated decision).
	 */

    function get_scrollBounds():Rectangle
    {
        return _scrollBounds.clone();
    }

    function set_scrollBounds(value:Rectangle):Rectangle
    {
        if (_explicitScrollBounds == value || (_explicitScrollBounds != null && value != null && _explicitScrollBounds.equals(value)))
            return null;
        _explicitScrollBounds = (value != null) ? value.clone() : null;
        invalidateScrollBounds();
        return value;
    }

    var _contentWidth:Float;

    function get_contentWidth():Float
    {
        return _contentWidth;
    }

    var _contentHeight:Float;

    function get_contentHeight():Float
    {
        return _contentHeight;
    }

    var _canScrollHorizontally:Bool;

    /**
	 * Wether viewport will move horizontally.
	 * 
	 * @see #updateCanScroll()
	 */

    function get_canScrollHorizontally():Bool
    {
        return _canScrollHorizontally;
    }

    var _canScrollVertically:Bool;

    /**
	 * Wether viewport will move vertically.
	 * 
	 * @see #updateCanScroll()
	 */

    function get_canScrollVertically():Bool
    {
        return _canScrollVertically;
    }

    var _inTouchInteraction:Bool;

    function get_inTouchInteraction():Bool
    {
        return _inTouchInteraction;
    }

    var _isScrolling:Bool;

    /**
	 * 
	 */

    function get_isScrolling():Bool
    {
        return _isScrolling;
    }

    /** @private */
    var _pagingEnabled:Bool;

    /**
	 * 
	 */

    function get_pagingEnabled():Bool
    {
        return _pagingEnabled;
    }

    function set_pagingEnabled(value:Bool):Bool
    {
        if (_pagingEnabled == value)
            return value;
        _pagingEnabled = value;
        invalidateScrollBounds();
        return value;
    }

    //--------------------------------------------------------------------------
    //
    //  Public methods
    //
    //--------------------------------------------------------------------------

    public function setPosition(x:Float, y:Float):Void
    {
        _positionX = x;
        _positionY = y;
    }

    public function setContentSize(width:Float, height:Float):Void
    {
        if (!(width >= 0) || !(height >= 0))
        {
            throw "Content size must be non negative. " + "Passed values: width = " + width + ", height = " + height;
        }
        _contentWidth = width;
        _contentHeight = height;

        invalidateScrollBounds();
    }

    /**
	 * Viewport size affects pull and bounce effects only.
	 * (So changing it is at any time should not bring any critical problems)
	 */

    public function setViewportSize(width:Float, height:Float):Void
    {
        if (!(width >= 0) || !(height >= 0))
        {
            throw "Viewport dimentions must be non negative. " + "Passed values: width = " + width + ", height = " + height;
        }
        _viewportWidth = width;
        _viewportHeight = height;
        invalidateScrollBounds();
    }

    public function stop():Void
    {
        _inTouchInteraction = false;
        _directionalLockTimer.reset();
        _lockHorizontal = _lockVertical = false;
        //TODO: maybe in onDragBegin?
        _isScrolling = false;
        if (_throwEffect != null && _throwEffect.isPlaying)
        {
            _throwEffect.stop(false);
        }
        snapToValidPosition();
    }

    public function dispose():Void
    {
        if (isScrolling)
        {
            stop();
        }
        if (_directionalLockTimer != null)
        {
            _directionalLockTimer.stop();
            _directionalLockTimer.removeEventListener(TimerEvent.TIMER, directionalLockTimer_timerHandler);
            _directionalLockTimer = null;
        }
        positionUpdateCallback = null;
    }

    public function onInteractionBegin(positionX:Float, positionY:Float):Void
    {
        stopThrowEffectOnTouch();
        _inTouchInteraction = true;
        setPosition(positionX, positionY);
        //TODO: or set fields directly?
        // touch while throw effect playing
        if (isScrolling)
        {
            clipToScrollBounds();
            if (directionalLock)
                // Touch while throw effect playing with some direction locked.
                // We want to preserve previous locked or free scrolling.
            {
                restartDirectionalLockWatch();
            }
            ;
        }
        ;
        // NB! set touch positions to field values, not arguments
        // because "clipToScrollBounds" may change value.
        _touchHSP = _positionX;
        _touchVSP = _positionY;
        _lastDirectionX = _lastDirectionY = 0;
        _cummulativeOffsetX = 0;
        _cummulativeOffsetY = 0;
        _velocityCalculator.reset();
    }

    public function onDragBegin(dx:Float, dy:Float):Void
    {
        updateCanScroll();
        _isScrolling = true;
        if (directionalLock)
            // TODO: optimize of fuckit?
        {
            _directionalLockThresholdAngleCoefficient = Math.sin(directionalLockThresholdAngle) * 2 / Math.sqrt(2);
        }
        ;
        onDragUpdate(dx, dy);
    }

    public function onDragUpdate(dx:Float, dy:Float):Void
    {
        if (directionalLock && canScrollHorizontally && canScrollVertically)
        {
            _directionalLockCummulativeOffsetX += dx;
            _directionalLockCummulativeOffsetY += dy;

            // We have not decided yet wheather locked or free scrolling
            //TODO: optimization. Options:
            // 1. precalculate square of directionalLockThresholdDistance
            // 2. use square zone instead of circle
            if (!_directionalLockTimer.running && !_lockHorizontal && !_lockVertical)
            {
                var dSqr:Float = Math.sqrt(_directionalLockCummulativeOffsetX * _directionalLockCummulativeOffsetX + _directionalLockCummulativeOffsetY * _directionalLockCummulativeOffsetY);

                // We are out of our "directional lock safe zone"
                // so we have to make decision now
                if (dSqr >= directionalLockThresholdDistance)
                {
                    var angle:Float = Math.atan2(_directionalLockCummulativeOffsetY, _directionalLockCummulativeOffsetX);
                    var threshold:Float = Math.sin(directionalLockThresholdAngle);
                    if (Math.abs(Math.sin(angle)) < threshold)
                    {
                        _lockHorizontal = true;
                        trace("directionalLock set to 'horizontal'");
                    }
                    else if (Math.abs(Math.cos(angle)) < threshold)
                    {
                        _lockVertical = true;
                        trace("directionalLock set to 'vertical'");
                    }
                    else
                    {
                        trace("directionalLock set to 'free'");
                    }

                    restartDirectionalLockWatch();
                }
            }
            else if (Math.abs(_directionalLockCummulativeOffsetX) >= directionalLockThresholdDistance || Math.abs(_directionalLockCummulativeOffsetY) >= directionalLockThresholdDistance)
            {
                // Looks like we are moving intensively enough
                restartDirectionalLockWatch();
            }
        }

        if (_lockVertical || !canScrollHorizontally)
            dx = 0;
        if (_lockHorizontal || !canScrollVertically)
            dy = 0;

        _lastDirectionX = ((canScrollHorizontally && dx != 0)) ? (dx > (0) ? 1 : -1) : 0;
        _lastDirectionY = ((canScrollVertically && dy != 0)) ? (dy > (0) ? 1 : -1) : 0;
        _velocityCalculator.addOffsets(dx, dy);

        performDrag(dx, dy);
    }

    public function onInteractionEnd():Void
    {
        _inTouchInteraction = false;
        _directionalLockTimer.reset();
        if (isScrolling)
        {
            var throwVelocity:Point = calculateThrowVelocity();
            performThrow(throwVelocity.x, throwVelocity.y);
        }

        else
        {
            performThrow(0, 0);
        }

    }

    public function performThrow(velocityX:Float, velocityY:Float):Void
    {
        if (Math.isNaN(velocityX) || Math.isNaN(velocityY))
            // Could be useful to catch velocity calculation bugs.
        {
            throw "One of the velocities is NaN.";
        }
        ;
        if (setupThrowEffect(velocityX, velocityY))
        {
            _throwEffect.play();
        }
    }

    //--------------------------------------------------------------------------
    //
    //  Protected methods
    //
    //--------------------------------------------------------------------------

    function setEffectiveScrollBounds(left:Float, top:Float, right:Float, bottom:Float):Void
    {
        _scrollBounds.left = left;
        _scrollBounds.top = top;
        _scrollBounds.right = right;
        _scrollBounds.bottom = bottom;
        updateCanScroll();
        validatePosition();
    }

    function getExplicitOrMeasuredScrollBounds():Rectangle
    {
        return _explicitScrollBounds != null ? _explicitScrollBounds : _measuredScrollBounds;
    }

    function updateCanScroll():Void
    {
        var scrollBounds:Rectangle = _scrollBounds;
        _canScrollHorizontally = (bounceEnabled && allwaysBounceHorizontal) || scrollBounds.width > 0;
        _canScrollVertically = (bounceEnabled && allwaysBounceVertical) || scrollBounds.height > 0;
    }

    function measureScrollBounds():Void
    {
        _measuredScrollBounds.left = 0;
        _measuredScrollBounds.top = 0;

        if (pagingEnabled)
        {
            _measuredScrollBounds.width = Math.max(0, Std.int(_contentWidth / _viewportWidth) - 1) * _viewportWidth;
            _measuredScrollBounds.height = Math.max(0, Std.int(_contentHeight / _viewportHeight) - 1) * _viewportHeight;
        }
        else
        {
            _measuredScrollBounds.width = Math.max(0, _contentWidth - _viewportWidth);
            _measuredScrollBounds.height = Math.max(0, _contentHeight - _viewportHeight);
        }
    }

    function invalidateScrollBounds():Void
    {
        measureScrollBounds();
        var scrollBounds:Rectangle = getExplicitOrMeasuredScrollBounds();
        setEffectiveScrollBounds(scrollBounds.left, scrollBounds.top, scrollBounds.right, scrollBounds.bottom);
    }

    /**
	 * Used to adjust scroll positions on interaction start (if it's currently pulled/bounces).
	 */

    function clipToScrollBounds():Void
    {
        var scrollBounds:Rectangle = _scrollBounds;
        var changed:Bool = false;
        if (_positionX < scrollBounds.left)
        {
            _positionX = scrollBounds.left;
            changed = true;
        }

        else if (_positionX > scrollBounds.right)
        {
            _positionX = scrollBounds.right;
            changed = true;
        }
        if (_positionY < scrollBounds.top)
        {
            _positionY = scrollBounds.top;
            changed = true;
        }

        else if (_positionY > scrollBounds.bottom)
        {
            _positionY = scrollBounds.bottom;
            changed = true;
        }
        if (changed)
        {
            positionUpdateCallback(_positionX, _positionY);
        }
    }

    function validatePosition():Void
    {
        var scrollBounds:Rectangle = _scrollBounds;
        if (_throwEffect != null && _throwEffect.isPlaying)
        {
            var needRethrow:Bool = false;
            if (!pagingEnabled)
                // Condition explanation:
                // _throwReachedEdgePosition == true means throw effect will bounce off the edge,
                // which is probably not desired given new scroll bounds.
            {
                if (_throwReachedEdgePosition || _throwFinalVSP > scrollBounds.bottom || _throwFinalVSP < scrollBounds.top || _throwFinalHSP > scrollBounds.right || _throwFinalHSP < scrollBounds.left)
                {
                    needRethrow = true;
                }
            }

            else if (getSnappedPosition(_throwFinalVSP, _viewportHeight, scrollBounds.top, scrollBounds.bottom) != _throwFinalVSP || getSnappedPosition(_throwFinalHSP, _viewportWidth, scrollBounds.left, scrollBounds.right) != _throwFinalHSP)
            {
                needRethrow = true;
            }
            //TODO: this case could be potentially improved
            // Stop the current animation and start a new one that gets us to the correct position.
            // Get the effect's current velocity
            if (needRethrow)
            {
                var velocity:Point = _throwEffect.getCurrentVelocity();
                // Stop the existing throw animation now that we've determined its current velocities.
                _throwEffect.stop(false);
                // Now perform a new throw to get us to the right position.
                if (setupThrowEffect(-velocity.x, -velocity.y))
                {
                    _throwEffect.play();
                }
            }
            ;
        }
        else if (_inTouchInteraction)
        {
            // We were in pull and still are - do nothing (i.e. "pull to refresh")
            // or we are simply out of the bounds now (unlikely to happen, TODO clip maybe)
            if (_positionX < scrollBounds.left || _positionX > scrollBounds.right)
            {
            }
            else
            {
                _touchHSP = _positionX;
                _cummulativeOffsetX = 0;
            }

            if (_positionY < scrollBounds.top || _positionY > scrollBounds.bottom)
                // We were in pull and still are - do nothing (i.e. "pull to refresh")
                // or we are simply out of the bounds now (unlikely to happen, TODO clip maybe)
            {
            }
            else
            {
                _touchVSP = _positionY;
                _cummulativeOffsetY = 0;
            }

        }

        else // No touch interaction is in effect, but the content may be sitting at
            // a scroll position that is now invalid.  If so, snap the content to
            // a valid position.
        {
            snapToValidPosition();
        }

    }

    function snapToValidPosition():Void
    {
        var scrollBounds:Rectangle = _scrollBounds;
        var pos:Float;
        var changed:Bool = false;
        pos = getSnappedPosition(_positionX, _viewportWidth, scrollBounds.left, scrollBounds.right);
        if (_positionX != pos)
        {
            _positionX = pos;
            changed = true;
        }
        pos = getSnappedPosition(_positionY, _viewportHeight, scrollBounds.top, scrollBounds.bottom);
        if (_positionY != pos)
        {
            _positionY = pos;
            changed = true;
        }
        if (pagingEnabled)
            //TODO: move this somewhere else maybe?
        {
            _currentPageHSP = _positionX;
            _currentPageVSP = _positionY;
        }
        ;
        if (changed)
        {
            positionUpdateCallback(_positionX, _positionY);
        }
    }

    /**
	 * Performs actual calculations for position update on pan (drag).
	 */

    function performDrag(dx:Float, dy:Float):Void
    {
        _cummulativeOffsetX += dx;
        _cummulativeOffsetY += dy;

        var viewportSize:Float = 0;
        //viewport width or height
        // More natural pull formula can be presented as y = f(x)
        // where x is pullProgress, y is resultingPullProgress.
        // resulting pullOffset = viewportSize * resultingPullProgress
        // It has these features:
        // resuling pullOffset always <= pullOffset (graph is always lower then y = x);
        // slope of f(x) is constant or gradually decreses.
        // http://graph-plotter.cours-de-math.eu/
        // 0.4*(1 - (1-x)^(1.5)) [1.5 == PULL_TENTION_FACTOR]
        // x/2
        var pullOffset:Float = 0;
        // >=0
        var pullProgress:Float = 0;
        // [0.. 1]
        var scrollBounds:Rectangle = _scrollBounds;
        var pullAllowed:Bool = (maxPull != maxPull || maxPull > 0);
        if (canScrollHorizontally)
        {
            var newHSP:Float = _touchHSP - _cummulativeOffsetX;
            if (newHSP < scrollBounds.left || newHSP > scrollBounds.right)
                // If we're pulling the list past its end, we want it to move
                // only a portion of the finger distance to simulate tension.
            {
                if (pullAllowed)
                {
                    viewportSize = _viewportWidth;
                    if (newHSP < scrollBounds.left)
                        // @deprecated simple tension formula:
                        // newHSP = scrollBounds.left + (newHSP - scrollBounds.left) * 0.5;
                        // more natural pull tension:
                    {
                        pullOffset = scrollBounds.left - newHSP;
                        pullProgress = pullOffset < (viewportSize) ? pullOffset / viewportSize : 1;
                        pullProgress = Math.min((maxPull != 0 ? maxPull : MAX_PULL_FACTOR) * (1 - Math.pow(1 - pullProgress, PULL_TENSION_FACTOR)), pullProgress);
                        newHSP = scrollBounds.left - viewportSize * pullProgress;
                    }

                    else // @deprecated simple tension formula:
                        // newHSP = scrollBounds.right + (newHSP - scrollBounds.right) * 0.5;
                        // more natural pull tension:
                    {
                        pullOffset = newHSP - scrollBounds.right;
                        pullProgress = pullOffset < (viewportSize) ? pullOffset / viewportSize : 1;
                        pullProgress = Math.min((maxPull != 0 ? maxPull : MAX_PULL_FACTOR) * (1 - Math.pow(1 - pullProgress, PULL_TENSION_FACTOR)), pullProgress);
                        newHSP = scrollBounds.right + viewportSize * pullProgress;
                    }

                }

                else
                {
                    newHSP = newHSP < (scrollBounds.left) ? scrollBounds.left : scrollBounds.right;
                }

            }
            _positionX = newHSP;
        }
        if (canScrollVertically)
        {
            var newVSP:Float = _touchVSP - _cummulativeOffsetY;
            // If we're pulling the list past its end, we want it to move
            // only a portion of the finger distance to simulate tension.
            if (newVSP < scrollBounds.top || newVSP > scrollBounds.bottom)
            {
                if (pullAllowed)
                {
                    viewportSize = _viewportHeight;

                    if (newVSP < scrollBounds.top)
                    {
                        // @deprecated simple tension formula:
                        // newVSP = scrollBounds.top + (newVSP - scrollBounds.top) * 0.5;
                        // more natural pull tension:
                        pullOffset = scrollBounds.top - newVSP;
                        pullProgress = pullOffset < (viewportSize) ? pullOffset / viewportSize : 1;
                        pullProgress = Math.min(
                            (maxPull != 0 ? maxPull : MAX_PULL_FACTOR) * (1 - Math.pow(1 - pullProgress, PULL_TENSION_FACTOR)), pullProgress);
                        newVSP = scrollBounds.top - viewportSize * pullProgress;
                    }
                    else
                    {
                        // @deprecated simple tension formula:
                        // newVSP = scrollBounds.bottom + (newVSP - scrollBounds.bottom) * 0.5;
                        // more natural pull tension:

                        pullOffset = newVSP - scrollBounds.bottom;
                        pullProgress = pullOffset < (viewportSize) ? pullOffset / viewportSize : 1;
                        pullProgress = Math.min((maxPull != 0 ? maxPull : MAX_PULL_FACTOR) * (1 - Math.pow(1 - pullProgress, PULL_TENSION_FACTOR)), pullProgress);
                        newVSP = scrollBounds.bottom + viewportSize * pullProgress;
                    }
                }
                else
                {
                    newVSP = newVSP < (scrollBounds.top) ? scrollBounds.top : scrollBounds.bottom;
                }

            }

            _positionY = newVSP;
        }
        positionUpdateCallback(_positionX, _positionY);
    }

    function restartDirectionalLockWatch():Void
    {
        _directionalLockCummulativeOffsetX = 0;
        _directionalLockCummulativeOffsetY = 0;
        //			_directionLockTimerStartPoint = panGesture.location;
        _directionalLockTimer.reset();
        _directionalLockTimer.start();
    }

    function calculateThrowVelocity():Point
    {
        var throwVelocity:Point = _velocityCalculator.calculateVelocity();
        if (throwVelocity.length < minVelocity)
        {
            throwVelocity.x = 0;
            throwVelocity.y = 0;
        }

        else if (!Math.isNaN(maxVelocity) && maxVelocity > minVelocity)
        {
            throwVelocity.normalize(maxVelocity);
        }
        return throwVelocity;
    }

    /**
	 *  @private
	 *  Set up the effect to be used for the throw animation
	 */

    function setupThrowEffect(velocityX:Float, velocityY:Float):Bool
    {
        if (_throwEffect == null)
        {
            _throwEffect = new ThrowEffect();
            _throwEffect.onUpdateCallback = onThrowEffectUpdate;
            _throwEffect.onCompleteCallback = onThrowEffectComplete;
        }
        var scrollBounds:Rectangle = _scrollBounds;
        var minX:Float = scrollBounds.left;
        var minY:Float = scrollBounds.top;
        var maxX:Float = scrollBounds.right;
        var maxY:Float = scrollBounds.bottom;
        var decelerationRate:Float = this.decelerationRate;
        if (pagingEnabled)
            // See whether a page switch is warranted for this touch gesture.
        {
            if (canScrollHorizontally)
            {
                _currentPageHSP = determineNewPageScrollPosition(velocityX, _positionX, _currentPageHSP, _viewportWidth, minX, maxX);
                // "lock" to the current page
                minX = maxX = _currentPageHSP;
            }
            if (canScrollVertically)
            {
                _currentPageVSP = determineNewPageScrollPosition(velocityY, _positionY, _currentPageVSP, _viewportHeight, minY, maxY);
                // "lock" to the current page
                minY = maxY = _currentPageVSP;
            }
            // Normally we don't want to see much of a bounce, so
            // Flex team attenuates velocity here,
            // but I think it's better to adjust friction to preserve correct starting velocity.
            decelerationRate *= 0.98;
        }
        ;
        //			_throwEffect.propertyNameX = canScrollHorizontally ? HORIZONTAL_SCROLL_POSITION : null;
        //			_throwEffect.propertyNameY = canScrollVertically ? VERTICAL_SCROLL_POSITION : null;
        _throwEffect.startingVelocityX = velocityX;
        _throwEffect.startingVelocityY = velocityY;
        _throwEffect.startingPositionX = _positionX;
        _throwEffect.startingPositionY = _positionY;
        _throwEffect.minPositionX = minX;
        _throwEffect.minPositionY = minY;
        _throwEffect.maxPositionX = maxX;
        _throwEffect.maxPositionY = maxY;
        _throwEffect.decelerationRate = decelerationRate;
        _throwEffect.viewportWidth = _viewportWidth;
        _throwEffect.viewportHeight = _viewportHeight;
        _throwEffect.pull = (maxPull > 0 || maxPull != maxPull);
        _throwEffect.bounce = bounceEnabled;
        _throwEffect.maxBounce = (maxBounce > (0) ? maxBounce : MAX_OVERSHOOT_FACTOR);
        //	        // In snapping mode, we need to ensure that the final throw position is snapped appropriately.
        ////	        _throwEffect.finalPositionFilterFunction = snappingFunction == null ? null : getSnappedPosition;
        //	        _throwEffect.finalPositionFilterFunction = snappingDelegate ? snappingDelegate.getSnappedPosition : null;
        _throwEffect.finalPositionFilterFunction = null;
        //FIXME: temporary line
        //TODO: delegate to adjust final position
        if (!_throwEffect.setup())
        {
            stop();
            return false;
        }
        _throwFinalHSP = _throwEffect.finalPosition.x;
        _throwFinalVSP = _throwEffect.finalPosition.y;
        _throwReachedEdgePosition = (_throwFinalVSP == maxY || _throwFinalVSP == minY || _throwFinalHSP == maxX || _throwFinalHSP == minX);
        return true;
    }

    /**
	 *  Stop the effect if it's currently playing and prepare for a possible scroll,
	 *  snap to valid scroll positions
	 */

    function stopThrowEffectOnTouch():Void
    {
        if (_throwEffect != null && _throwEffect.isPlaying)
            // stop the effect.  we don't want to move it to its final value...we want to stop it in place
        {
            _throwEffect.stop(false);
        }
        ;
    }

    /**
	 *  This function determines whether a switch to an adjacent page is warranted, given 
	 *  the distance dragged and/or the velocity thrown. 
	 */

    function determineNewPageScrollPosition(velocity:Float, position:Float, currPagePosition:Float, viewportSize:Float, minPosition:Float, maxPosition:Float):Float
    {
        var stationaryOffsetThreshold:Float = viewportSize * 0.5;
        var pagePosition:Float;
        // Check both the throw velocity and the drag distance. If either exceeds our threholds, then we switch to the next page.
        if (velocity < -minVelocity || position >= currPagePosition + stationaryOffsetThreshold)
            // Go to the next page
            // Set the new page scroll position so the throw effect animates the page into place
        {
            pagePosition = Math.min(currPagePosition + viewportSize, maxPosition);
        }

        else if (velocity > minVelocity || position <= currPagePosition - stationaryOffsetThreshold)
            // Go to the previous page
        {
            pagePosition = Math.max(currPagePosition - viewportSize, minPosition);
        }

        else // Snap to the current one
        {
            pagePosition = currPagePosition;
        }

        // Ensure the new page position is snapped appropriately
        pagePosition = getSnappedPosition(pagePosition, viewportSize, minPosition, maxPosition);
        return pagePosition;
    }

    /**
	 *  This function takes a scroll position and the associated property name, and finds
	 *  the nearest snapped position (i.e. one that satifises the current scrollSnappingMode).
	 */

    function getSnappedPosition(position:Float, viewportSize:Float, minPosition:Float, maxPosition:Float):Float
    {
        //			if (pagingEnabled && !snappingDelegate)//TODO different condition if custom snapping defined

        {
            if (pagingEnabled)
                // If we're in paging mode and no snapping is enabled, then we must snap
                // the position to the beginning of a page. i.e. a multiple of the
                // viewport size.
            {
                if (viewportSize > 0)
                    // If minPosition is NaN or some Infinity we use 0 as a base.
                {
                    var basePosition:Float = (((minPosition * 0) == 0)) ? minPosition : 0;
                    position = basePosition + Math.round(position / viewportSize) * viewportSize;
                }
                ;
            }
            ;
            //			else if (snappingDelegate)
            //			{
            //				position = snappingDelegate.getSnappedPosition(position, propertyName);
            //			}
            // Clip to scroll bounds (manually for performance and bulletproof NaN/Infinity)
            if (position < minPosition)
            {
                position = minPosition;
            }

            else if (position > maxPosition)
            {
                position = maxPosition;
            }
            //TODO: to round or not to round?
            return position;
        }

    }

    //--------------------------------------------------------------------------
    //
    //  Event handlers
    //
    //--------------------------------------------------------------------------

    function directionalLockTimer_timerHandler(event:TimerEvent):Void
    {
        //			if (_directionLockTimerStartPoint.subtract(panGesture.location).length < Gesture.DEFAULT_SLOP)
        //			{

        {
            _lockHorizontal = _lockVertical = false;
            trace("directionalLock reset");
        }

    }

    function onThrowEffectUpdate(positionX:Float, positionY:Float):Void
    {
        _positionX = positionX;
        _positionY = positionY;
        positionUpdateCallback(_positionX, _positionY);
    }

    function onThrowEffectComplete():Void
    {
        stop();
        if (throwCompleteCallback != null)
            throwCompleteCallback();
    }

}

