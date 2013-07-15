var flightPath = null;
var Clouds = null;
var map = null;
// Initalization Function:
var Views = new Object();
Views.displayView = displayView; 
Views.displayClouds = displayClouds;
Views.hideClouds = hideCLouds; 


function initialize() {


  // Google Initilize 
  var myLatLng = new google.maps.LatLng(65, -18);
   Clouds = new Object();
   Clouds.lst = new Array();
   Clouds.addCloud = addCloud;

  console.log("Added Ijsland");
  var mapOptions = {
    zoom: 7,
    center: myLatLng,
    mapTypeId: google.maps.MapTypeId.TERRAIN
  };

  console.log("AL: " + Clouds.lst.length);
  map = new google.maps.Map(document.getElementById("map_canvas"), mapOptions);
  Clouds.addCloud(map, 64.0, -18.0, "Ijsland");
  console.log("AL: " + Clouds.lst.length);
  Views.displayClouds();
  Views.hideClouds();
	

}

// Clouds zijn lowest level en anltijd zichbaar. 
function addCloud(map, lat, lng, cname) 
{
  	console.log("Creating new Object");
	var cloud = new Object();
	cloud.lat = lat;
	cloud.lng = lng;
	cloud.name = cname; 
	console.log(lat + " " + lng + " " + cname);
 	cloud.marker = new google.maps.Marker({ 
 		position: new google.maps.LatLng(lat, lng),
 		zoom: 7,
        	map: null,
        	title: cname
	 });
  	Clouds.lst[Clouds.lst.length].maker.setMap(null);
	Clouds.lst.append(cloud); 
}

function displayClouds()
{
	for (var i = 0; i < this.Clouds.length; i++)
	{
		 this.Clouds[i].marker.setMap(map);
	}
}

function hideClouds()
{
	for (var i = 0; i < this.Clouds.length; i++)
	{
		 this.Clouds[i].marker.setMap(null);
	}

}

function displayView(vnum, map) 
{
	for ( var i =0; i < this.view[vnum].instance.length; i++)
	{
		this.view[vnum].instance[i].setMap(this.map);
	}

	for ( var i =0; i < this.view[vnum].vpn.length; i++)
	{
		this.view[vnum].vpn[i].setMap(this.map);
	}
}





//  var flightPlanCoordinates = [
//    new google.maps.LatLng(37.772323, -122.214897),
//    new google.maps.LatLng(21.291982, -157.821856),
//    new google.maps.LatLng(-18.142599, 178.431),
//    new google.maps.LatLng(-27.46758, 153.027892)
//  ];
//
//  flightPath = new google.maps.Polyline({
//    path: flightPlanCoordinates,
//    strokeColor: "#FF0000",
//    strokeOpacity: 1.0,
//    strokeWeight: 2
//  });
  //flightPath.setMap(views.map);




// var clicked = 0;
// var twice = 0; 
// var marker2 = new google.maps.Marker({ 
// 	position: new google.maps.LatLng(51.4718, -0.14323),
// 	zoom: 7,
  //       map: map,
    //     title: "Cloud Xa"
// });

// function Clicked() {
// 	if (clicked == 0) 
// 	{
  // 		flightPath.setMap(null);
// 		clicked = 1;
// 		var myLatlng = new google.maps.LatLng(-25.363882,131.044922);
// 		var marker = new google.maps.Marker({
// 		    position: myLatlng,
  //   		    title:"Hello World!"
// 		});
// 		marker.setMap(map);
// 
// 	} else 
// 	{
  // 		flightPath.setMap(map);
// 		clicked = 0;
// 		twice = twice + 1;
// 		if ( twice == 2) {
// 			flightPath.strokeColor = "00FF00";
// 			flightPath.setMap(map);
// 		}
// 	}
// }


// function JumpToEngland() {
// 	map.setCenter(marker2.getPosition());
// }	
