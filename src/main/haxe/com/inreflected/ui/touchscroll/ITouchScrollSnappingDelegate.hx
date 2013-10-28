package com.inreflected.ui.touchscroll;

/**
 * @author Pavel fljot
 */
interface ITouchScrollSnappingDelegate
{
    function getSnappedPosition(position:Float, propertyName:String):Float;

    function getSnappedPositionOnResize(position:Float, propertyName:String, prevViewportSize:Float):Float;
}

