KOI Ponderer
============
An OS-X interactive viewer for long-candence light-curves from NASA's Kepler spacecraft.
________________________________________________________________________________________
KOI is an acronym for Kepler Object of Interest -- a star with intensity variations that might be due to eclipses from an exoplanet.
The Kepler spacecraft carried a telescope system designed to stare intently at over 100,000 stars, precisely recording their light, so that any eclipses caused by orbiting planets could be detected and analyzed. The processing of this data was an enormous task, requiring attention to detail, precise correction for known instrumental effects, and the search for signals obscured by a variety of nasty noises.

The data displays and diagnostic materials were useful for professionals with a detailed understanding of the system, but were overwhelming for a less-experienced person trying to get “a feel for the data”.

KOI Ponderer was developed as an attempt to use hand/eye coordination to “impedance match” the Kepler light-curve data to an understanding of the exoplanet orbits derived from it.  What follows here will only be as precise in its nomenclature as is needed to understand the basic items that appear in the app’s interface. 

The first entity to be considered is an individual star, which NASA assigns a unique 8-digit identifier (e.g. 11968463).  Associated with each star are one or more “long cadence” light-curves. These curves integrate the star’s light flux over half-hour intervals for up to 90 days; the quarter-year reflects spacecraft operational limitations.  If analysis of a star’s light-curves reveals a possible sequence of eclipses, then the star becomes a “Kepler Object of Interest” and is assigned a KOI identifier (e.g. K02433).  Each potential sequence of eclipses is identified by appending a hundreths decimal to the KOI identifier, e.g. K02433.01 to K02433.07 identify seven potential exoplanets orbiting this star.

Each potential exoplanet is characterized by a suite of orbital (and stellar) parameters derived from the details of the light curve.  We will not explicitly consider the stellar parameters, nor any inter-planet resonance interactions.

Within KOI Ponderer, each potential (candidate) orbit is defined by:

	* period -- The time interval (in days) between eclipses.
	* epoch -- A time (in days) when (the center) of an eclipse occurred.  This parameter is not unique, 
	since eclipses occurred both before and after the recorded epoch.
	* duration -- The time in hours between the beginning and end of each eclipse.
	* ingress -- The time in hours between when the eclipse begins and when the planet is fully overlapping 
	the star’s surface.
	* depth -- The maximum fraction of the star’s light (in parts-per-million) that the exoplanet obscures.

The KOI Ponderer application initially contains a database of some seven thousand candidate eclipse parameter records.  Each star that shows eclipses is also represented in the database, but, to save disk space, the light-curves associated with all the stars are not immediately available.  The expected work flow starts with selection of one of the stars, downloading the associated light-curves, and displaying those light-curves aligned according to the orbital parameters of one of its candidate eclipse sequences.  At this point, various orbital and display parameters can be interactively modified to provide insight into the analysis, particularly with respect to the effect of phenomena that are not incorporated into the design of the analysis software.

### Implementation and Testing
	* OS-X 10.9.4
	* MacBook Pro Retina 13-inch, late 2013
	* iMac 21.5-inch, mid 2010
	
### Features
	* Easy download of Kepler-1 light-curves by KOI or star id.
	* Interactive modification of display's time and flux scales (using OpenGL).
	* "Stacked" summation of flux values for period and epoch.
	* Colored marking of all eclipse sequences to highlight potential interferences.
	* Basic ability to compute and remove/add simple eclipse curves to data.
	
### To Build
	* Obtain Xcode from the Mac App Store
	* Use Safari to view https://github.com/rbnerf/KOIponderer#koi-ponderer
	* At lower right, press button [Download ZIP]
	* When download is complete, file will be unzipped into a directory
	named KOIponderer-master
	* Use Finder to view the contents of that directory
	* Double-click on KOIponderer.xcodeproject; Xcode will launch.
	* If you are not an "Admin" user, make sure the "Scheme" at upper left
	is KOIrelease, rather than KOIponderer.
	* Press the Arrow key at upper right to initiate Build/Run.
	* "Normal" error messages: 
		Downloader.xib -- Unsupported configuration
		Images.xcassets -- A bunch of contradictory complaints about image dimensions.
	* The app should launch -- follow the directions in KOIponderer.pdf
