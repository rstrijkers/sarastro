var Clouds = null;
var Views = null;
var map = null;

var contentString = '<div id="content"></div>';
var infowindow = new google.maps.InfoWindow({
    content: contentString
});




function initialize()
{
	// Cloud Object 
	Clouds = new Object();
	Clouds.clouds = {};   // individual clouds
      Clouds.cloudGeoLocations = {};
      Clouds.cloudProviders = {};
	Clouds.addCloud = addCloud;	
	Clouds.showInstances = showInstances;
	Clouds.hideInstances = hideInstances;
	Clouds.addInstance = addInstance;
	Clouds.delInstance = delInstance;
      Clouds.getClouds = getClouds;
      Clouds.markers = []; 
      Clouds.markerCluster = null;
      Clouds.openDialog = null;
	// View 
	Views = new Object();

	// Google Maps 
  	var myLatLng = new google.maps.LatLng(0, 0);
 	var mapOptions = {
    		zoom: 3,
    		center: myLatLng,
    		mapTypeId: google.maps.MapTypeId.TERRAIN
  	};
  	map = new google.maps.Map(document.getElementById("map_canvas"), mapOptions);
      Clouds.getClouds(Clouds);

     // console.log(Clouds.markers);

     // console.log(Clouds.markerCluster);

}


function getClouds(Clouds)
{
   $.getJSON('cgeo.json', function(data) {
      $.each(data, function(key, val) {
         var t = new Object();
         t.lat = val.lat;
         t.lng = val.lng;
         Clouds.cloudGeoLocations[val.zone] = t; 
      })
   }).complete($.getJSON('cloc.json', function(data) {
      $.each(data, function(key, val) {
         Clouds.cloudProviders[val.cpid] = val.locations;
         for( loc in val.locations.zones  ) 
         {  
            if(Clouds.cloudGeoLocations[val.locations.zones[loc]] != null){
                Clouds.addCloud(val.locations.zones[loc],
                    val.locations.region,
                    Clouds.cloudGeoLocations[val.locations.zones[loc]].lat, 
                    Clouds.cloudGeoLocations[val.locations.zones[loc]].lng ); 
             }
            else {
                console.log("missing : " + val.locations.zones[loc]);
            }
         }
         // push. 
      });

     // console.log("====");
     // console.log(Clouds.markers);
     // console.log("====1");
     // Clouds.markerCluster = new google.maps.OverlayView.markerClusterer(map,{markers: Clouds.markers});
    //  console.log("====2");
     // Clouds.markerCluster.refresh();
      //console.log(Clouds.cloudProviders);
   }));
}

function addCloud(cname, region, lat, lng)
{
	//console.log("adding cloud :" + cname + " " + lat + " " + lng );
	var cloud = new Object();
	cloud.instances = {};
	cloud.cname = cname; 
	cloud.lat = lat;
	cloud.lng = lng; 
	cloud.lvl = 0;
      var image = 'cloud.png';
	// Fix marker
 	cloud.marker = new google.maps.Marker({ 
 		position: new google.maps.LatLng(lat, lng),
 		zoom: 3,
        	map: map, 
        	title: cname,
            animation: google.maps.Animation.DROP,
           //icon: image
	 });
      google.maps.event.addListener(cloud.marker, 'click', function() {
            $.get('test.html', function(data) {
            }).complete(function(data) {
               console.log(data.responseText);
               var info =  new google.maps.InfoWindow({
                     content: cname + "  " + data.responseText
               });
               if ( Clouds.openDialoge != null )
               {
                  Clouds.openDialoge.close(); 
               }
               info.open(map,cloud.marker); 
               Clouds.openDialoge = info; 
            });
      });
     
      this.markers.push(cloud);
      
      //console.log(this.markers);      
	this.clouds[cname] = cloud;
      
}


function addInstance(cname, iname, lvl)
{
	console.log("adding instance : " + iname + " in cloud " + cname + " vnet " + lvl);


	var inst = new Object();
	inst.name = iname;
	inst.vpns = {};
	inst.lvl = lvl;
	inst.marker = new google.maps.Marker({
		position: new google.maps.LatLng(64.1, -18.0),
		zoom: 7,
		map: map,
		title: iname
	});

	this.clouds[cname].instances[iname] = inst; 
}

function delInstance(cname, iname)
{
	// aanroepen rudolfs functie
	console.log("Deleting instance : " + iname + " in cloud " + cname);
	// TODO remove VPN
	
	this.clouds[cname].instances[iname].marker.setMap(null);
	this.clouds[cname].instances[iname] = null;
}

function hideInstances(level)
{
	console.log("Hiding lvl: " + level);
	for( c in this.clouds) 
	{
		console.log(c);
		for( i in this.clouds[c].instances )
		{
			console.log("Inst " + this.clouds[c].instances[i].level);
			console.log(this.clouds[c].instances[i]);
			if ( this.clouds[c].instances[i].lvl == level) 
			{
				console.log("Hiding: " + this.clouds[c].instances[i].iname);
				this.clouds[c].instances[i].marker.setMap(null);
			}
		}
	}
}

function showInstances(level)
{
	console.log("Showing level: " + level);
	for( c in this.clouds) 
	{
		console.log(c);
		for( i in this.clouds[c].instances )
		{
			console.log("Inst " + this.clouds[c].instances[i].level);
			console.log(this.clouds[c].instances[i]);
			if ( this.clouds[c].instances[i].lvl == level) 
			{
				console.log("showing: " + this.clouds[c].instances[i].name);
				this.clouds[c].instances[i].marker.setMap(map);
			}
		}
	}
}


function toggleBounce() {
  console.log("toggle Bounce()");
  if (marker.getAnimation() != null) {
    marker.setAnimation(null);
  } else {
    marker.setAnimation(google.maps.Animation.BOUNCE);
  }
}


function addVPN(cname1, iname1, cname2, iname2)
{
}

