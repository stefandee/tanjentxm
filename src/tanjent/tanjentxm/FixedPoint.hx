/* Licensed under The MIT License (MIT), see license.txt*/
package tanjent.tanjentxm;

import haxe.macro.Expr;

/** <p>
 * Provides macros and functions for converting floating point values to fixed-point integers and back. 
 * </p>
 * <p>
 * Decimal resolution is 1 / FP_SHIFT.
 * If FP_SHIFT is > 15 on a 32 bit system it will overflow when multiplied, causing nasty distortion or silence.
 * If FP_SHIFT is < 10 there will be either brutal quantization noise or silence.
 * </p>
 * @author Jonas Murman */
class FixedPoint
{

	/// Set to 14 to give some headroom for modules with many loud samples playing simultanously
	public static inline var FP_SHIFT:Int = 14;

	/// Bitwise AND-mask to get the fractional part of a FP number
	public static inline var FP_FRAC_MASK:Int = ((1 << FP_SHIFT) - 1);
	
	/// Multiply a floating point number by this to get the FP representation
	public static inline var FP_FLOAT_MUL:Float = (1 << FP_SHIFT);	
	
	/// Multiply a FP number by this to get a floating point representation
	public static inline var FP_FLOAT_MUL_INV:Float = (1.0 / (1 << FP_SHIFT));	

#if (haxe_ver < 4)
	/// Macro to convert a floating point value to a fixed point (FP) representation.
	macro public static function FLOAT_TO_FP(f:Expr):Expr
	{
		return macro Std.int($f * tanjent.tanjentxm.FixedPoint.FP_FLOAT_MUL);
	}
#else
	/// TODO use templates if necessary
	public static function FLOAT_TO_FP(f:Float):Int
	{
		return Std.int(f * tanjent.tanjentxm.FixedPoint.FP_FLOAT_MUL);
	}
#end	
		
	/// Macro to convert a fixed point (FP) value to a floating point value
	macro public static function FP_TO_FLOAT(fp:Expr):Expr
	{
		return macro $fp * tanjent.tanjentxm.FixedPoint.FP_FLOAT_MUL_INV;
	}
	
	public static var FP_HALF:Int = FixedPoint.FLOAT_TO_FP(0.5);
	public static var FP_ONE:Int = FixedPoint.FLOAT_TO_FP(1.0);
                  
	public static var FP_ZERO_POINT_05:Int = FixedPoint.FLOAT_TO_FP(0.05);
	public static var FP_ZERO_POINT_95:Int = FixedPoint.FLOAT_TO_FP(0.95);
	
	public function new() 
	{
		
	}
	
}