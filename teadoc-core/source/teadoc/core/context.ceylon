
interface TeadocLoadout {
	
	shared formal void affect(TeadocContext cxt) ;
}

class TeadocContext({TeadocLoadout | TeadocContext*} loadouts) {
	
	//TODO: load phase
	//TODO: force initialization
	//TODO: resolve injections
	//TODO: circular init protection
	//TODO: definitions -> function, needle, value, class, w/ addl post processing
}