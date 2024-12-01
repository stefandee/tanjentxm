/* Licensed under The MIT License (MIT), see license.txt*/
package tanjent.tanjentxm;

/** <p>
 * Holds a Note entry of an {@link XMPattern} 
 * </p>
 * @author Jonas Murman */
class XMNote
{	
	public var note:Int;
	public var instrument:Int;
	public var volume:Int;
	public var effectType:Int;
	public var effectParameter:Int;
	
	public function new() 
	{
		this.reset();
	}
	
	public function reset()
	{
		this.note = 0;
		this.instrument = 0;
		this.volume = 0;
		this.effectType = 0;
		this.effectParameter = 0;		
	}
}