#include <vector>
#include <QString>
#include <list>
#include "Meteor.hpp"
#include "Constellation.hpp"
#include "StelObject.hpp"
#include "SolarSystem.hpp"
#include "Planet.hpp"
;

CREATE STRUCT VIEW AllMeteors (
       FOREIGN KEY(meteor_id) FROM self references Meteor POINTER
);

CREATE VIRTUAL TABLE SolarSystem.AllMeteors 
       USING STRUCT VIEW AllMeteors
       WITH REGISTERED C NAME active
       WITH REGISTERED C TYPE vector<Meteor*>;

CREATE STRUCT VIEW Meteor (
       alive BOOL FROM isAlive(),
       startHeight DOUBLE FROM startH,
       endHeight DOUBLE FROM endH,
       velocity DOUBLE FROM velocity,
       magnitude FLOAT FROM mag,
       observDistance DOUBLE FROM xydistance,
       scaleMagnitude DOUBLE FROM distMultiplier
);

CREATE VIRTUAL TABLE SolarSystem.Meteor 
       USING STRUCT VIEW Meteor
       WITH REGISTERED C TYPE Meteor;

CREATE STRUCT VIEW AllPlanets (
       FOREIGN KEY(planet_id) FROM data() REFERENCES Planet POINTER
);

CREATE VIRTUAL TABLE SolarSystem.AllPlanets 
       USING STRUCT VIEW AllPlanets
       WITH REGISTERED C NAME allPlanets
       WITH REGISTERED C TYPE list<PlanetP>;

CREATE STRUCT VIEW Planet (
       name STRING FROM getNameI18n().toStdString(),       
       hasAtmosphere BOOL FROM hasAtmosphere(),
       radius DOUBLE FROM getRadius(),
       period DOUBLE FROM getSiderealDay(),
       rotObliquity DOUBLE FROM getRotObliquity(),
       distance DOUBLE FROM getDistance(),
       cloudDensity DOUBLE FROM cloudDensity,
       cloudScale FLOAT FROM cloudScale,
       cloudSharpness FLOAT FROM cloudSharpness,
       albedo FLOAT FROM albedo,
       axisRotation FLOAT FROM axisRotation,
//       FOREIGN KEY(parentPlanet_id) FROM parent.data() REFERENCES Planet POINTER,
       FOREIGN KEY(satellites_id) FROM getStdSatellites() REFERENCES SatellitePlanets POINTER
);

CREATE VIRTUAL TABLE SolarSystem.Planet 
       USING STRUCT VIEW Planet
       WITH REGISTERED C TYPE Planet;

CREATE STRUCT VIEW SatellitePlanets (
       FOREIGN KEY(satellite_id) FROM data() REFERENCES Planet POINTER
);

CREATE VIRTUAL TABLE SolarSystem.SatellitePlanets 
       USING STRUCT VIEW SatellitePlanets
       WITH REGISTERED C TYPE list<QSharedPointer<Planet> >*;

CREATE STRUCT VIEW AllConstellations (
       FOREIGN KEY(constellation_id) FROM self REFERENCES Constellation POINTER
);

CREATE VIRTUAL TABLE SolarSystem.AllConstellations 
       USING STRUCT VIEW AllConstellations
       WITH REGISTERED C NAME asterisms
       WITH REGISTERED C TYPE vector<Constellation*>;

CREATE STRUCT VIEW Constellation (
       constelName STRING FROM getNameI18n().toStdString(),
//       FOREIGN KEY(brightestStar_id) FROM getBrightestStarInConstellation().data() REFERENCES StelObject POINTER,
//       FOREIGN KEY(starList_id) FROM asterism->data() REFERENCES StelObject POINTER
);

CREATE VIRTUAL TABLE SolarSystem.Constellation 
       USING STRUCT VIEW Constellation
       WITH REGISTERED C TYPE Constellation;

CREATE STRUCT VIEW StelObject (
       starName STRING FROM getNameI18n().toStdString(),
       starSciName STRING FROM getEnglishName().toStdString(),
       starType STRING FROM getType().toStdString()
);

CREATE VIRTUAL TABLE SolarSystem.StelObject 
       USING STRUCT VIEW StelObject
       WITH REGISTERED C TYPE StelObject;