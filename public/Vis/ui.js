
	//  Using the project template example from arbor.js
var sys;
var showinfo;
var showinfo_node;
var mode = "info";
var Renderer;

	// ------ some linear algebra to get the edge
function dist(x,y,x2,y2,x3,y3) {
  var dx = x - x2;
  var dy = y - y2;  
  a = dy/dx;
  b = y-a*x;

  // y = ax+b
  var ny = a*x3+b;
  // x = (y-b)/a
  var nx = (y3-b)/a;

  return {x:Math.abs(ny-y3), y:Math.abs(nx-x3)};  
}
	
// Return the index of the edge array based on the above distance
// No divide by zero testing, just hope the values are random enough that
// this is unnecessary.
function select_edge(edges, x, y) {  
  var smal = {x:999999, y:999999};
  var r = -1;
  $.each(edges, function(i, v) {
    d = dist(v.source._p.x, v.source._p.y, v.target._p.x, v.target._p.y,x,y);
    if(d.x < smal.x) {
      smal.x = d.x;
      r = i;        
    }
    if(d.y < smal.y) {
      smal.y = d.y;
      r = i;
    }
  })
  return edges[r];
}
			
		
// XXX: This is optimized. Selects the edges connected to
//   the nearest node and calculated distance to those 
//   nodes.
// 
function delete_edge(edges, point){
	e = select_edge(edges, point.x, point.y)
	
	$('.result').html("deleting edge: {" + e.source + ", " , e.target + "}")
	
	// delete the node
	$.ajax({
 		type: 'DELETE',
 		url: "/netapp/link/id/".concat(e.source.name + ":" + e.target.name),
 // MXM FIX 		data: "vid=<%= vid %>",
 		data: "vid=1",
 		dataType: 'text'
 	}).done(function(result) { 
		sys.numedges-=1				
	})
}		
	
function get_netapps() {			
  
	console.log("heeelooo")

	// MXM FIX jQuery.get('/netapp', {vid :<%= vid %>}, function(data) {				
	jQuery.get('/netapp', {vid :  "7" }, function(data) {				
		noodes = {}
		edgees = {}
		
		$('.result').html("getting netapps")
		d = jQuery.parseJSON(data)
		if(d) {
			$.each(d, function(i, v) {
			  // node data - refactor for d3
			  addnode(1,1,2)
			
			  console.log("status of node " + v.requestid + " is " + v.status)
			
			  noodes[v.requestid] = {id:String(v.requestid), alone:true, mass:.25, pending: v.status}
			})
		}
		//MXM FIX jQuery.get('/netapp/links', {vid :<%= vid %>}, function(data) {				
		jQuery.get('/netapp/links', {vid : "7" }, function(data) {				
			$('.result').html("getting links")
			d = jQuery.parseJSON(data)
			if(d) {
				$.each(d, function(i, v) {
					if(v.output) {
					s = String(v.output.client)			// set client id in edge object		
					d = String(v.output.server)		    // set server id in edge object
					a = {pending:v.status}				// set status in edge object
					if(edgees[d] == undefined) {
						if(!edgees[s]) edgees[s] = {}
						edgees[s][d] = a	
					} else {
						if(!edgees[d][s]) {
							if(!edgees[s]) edgees[s] = {}
							edgees[s][d] = a
						}							
					}
					}
				})
			}
			//sys.merge({nodes:noodes, edges:edgees})
			// XXX: Due to a bug (or feature...) we cannot start the system 
			//      without two nodes.
			//sys.addNode('invisible1',{invisible:true, mass:.25})
			//sys.addNode('invisible2',{invisible:true, mass:.25})					
		});
	});			
}
	
function flipmode(m) {
	mode = m
	switch(m) 
	{
		case "info":
			$('div.mode_info').css('font-weight', 'bold', 'background-color', '#AABBFF');
			$('div.mode_info_edge').css('font-weight', 'normal', 'background-color', '#AABBFF');
			$('div.mode_draw').css('font-weight', 'normal','background-color', '#AABBFF');
			$('div.mode_del_node').css('font-weight', 'normal','background-color', '#AABBFF');
			$('div.mode_del_edge').css('font-weight', 'normal','background-color', '#AABBFF');
		break;
		case "info_edge":
			$('div.mode_info').css('font-weight', 'normal', 'background-color', '#AABBFF');
			$('div.mode_info_edge').css('font-weight', 'bold', 'background-color', '#AABBFF');
			$('div.mode_draw').css('font-weight', 'normal','background-color', '#AABBFF');
			$('div.mode_del_node').css('font-weight', 'normal','background-color', '#AABBFF');
			$('div.mode_del_edge').css('font-weight', 'normal','background-color', '#AABBFF');
		break;
		case "draw":
			$('div.mode_info').css('font-weight', 'normal','background-color', '#AABBFF');
			$('div.mode_info_edge').css('font-weight', 'normal', 'background-color', '#AABBFF');				
			$('div.mode_draw').css('font-weight', 'bold', 'background-color', '#AABBFF');
			$('div.mode_del_node').css('font-weight', 'normal','background-color', '#AABBFF');
			$('div.mode_del_edge').css('font-weight', 'normal','background-color', '#AABBFF');
		break;
		case "del_node":
			$('div.mode_info').css('font-weight', 'normal','background-color', '#AABBFF');
			$('div.mode_info_edge').css('font-weight', 'normal', 'background-color', '#AABBFF');					
			$('div.mode_draw').css('font-weight', 'normal','background-color', '#AABBFF');
			$('div.mode_del_node').css('font-weight', 'bold', 'background-color', '#AABBFF');
			$('div.mode_del_edge').css('font-weight', 'normal','background-color', '#AABBFF');					
		break;
		case "del_edge":
			$('div.mode_info').css('font-weight', 'normal','background-color', '#AABBFF');
			$('div.mode_info_edge').css('font-weight', 'normal', 'background-color', '#AABBFF');					
			$('div.mode_draw').css('font-weight', 'normal','background-color', '#AABBFF');
			$('div.mode_del_node').css('font-weight', 'normal','background-color', '#AABBFF');
			$('div.mode_del_edge').css('font-weight', 'bold', 'background-color', '#AABBFF');
		break;	
	};
}

function get_locations() {
	jQuery.get('/api/cp/locations', {}, function(data) {
		var res = "<form id=\"zone\">"
		d = jQuery.parseJSON(data.substr(14))

		$.each(d, function(i, v) {
			$.each(v.locations.zones, function(j,w) {
				res+=w + ": <input type=\"radio\" name=\"z\" value=\"" + w + "\">"	
			})
		})
		
    $('.locations').html(res + "</form>");
  });	
}


function get_locations_option_list() {
  console.log("list");
  jQuery.get('/api/cp/locations', {}, function(data) {
    var res = "<form id=\"zone2\"><select name=\"zones_select\">"

	console.log(data.substr(14))
	
  	d = jQuery.parseJSON(data.substr(14))

    $.each(d, function(i, v) {
      $.each(v.locations.zones, function(j,w) {
        if ( w != "" ){
          res+= ": <option value=\"" + w + "\">"	+ w + "</option>"
        }
		  })
    })
			
    $('.locations_option_list').html(res + "</select></form>");

    var inputnumber = "<form id = \"numclouds\"><select name=\"number_of_instances\">";
    for( var i = 1; i <= 10;i++)  
    { 
      inputnumber += "<option value=\""+ i +"\">" + i + "</option>";
    }
    $('.loc_num').html( inputnumber + "</select></form>");
  });	
}





	
function execute_app() {
  var data = $('#appform').serializeArray()
	app = data[0].value

      // MXM FIX  location 
	jQuery.post("/vi/1/run", {"name" : app}, function(data) {		
		$('.result').html("Executing " + app + " on Virtual Internet.");
	});
	return false // don't submit form
}
	
function get_apps() {
	jQuery.get('/vi/apps', {}, function(data) {
		var res = "<form id=\"appform\" onsubmit=\"return execute_app()\">"
		d = jQuery.parseJSON(data)

		res+="<select name=\"app\">"	
		$.each(d, function(i, v) {
				res+="<option value=\"" + v + "\">" + v
				res+="</option>"				
		})
		res+="</select>"
		
		$('.apps').html(res + "<input type=\"submit\" value=\"run\"/></form>");
	});	
}

function execute_process() {
	var data = $('#singleappform').serializeArray()
	nid = data[1].value
	app = data[0].value

  // MXM fix 1 ( between vid and name   
  //jQuery.post("/netapp/" + nid + "/run", {"vid" : "1", "name" : app}, function(data) {		
  jQuery.post("/netapp/" + nid + "/run", {"vid" : "1", "name" : app}, function(data) {		
		$('.result').html("Executing " + app + " on " + nid + ".");
	});
	return false // don't submit form
}

function get_apps_single() {
	jQuery.get('/vi/apps', {}, function(data) {
		var res = "<form id=\"singleappform\" onsubmit=\"return execute_process()\">"

		// Get apps
		d = jQuery.parseJSON(data)		
		res+="<select name=\"app\">"	
		$.each(d, function(i, v) {
				res+="<option value=\"" + v + "\">" + v
				res+="</option>"
		})
		res+="</select>"
		
		// Get netapps
		var res2 = "<select name=\"nid\">"
		// MXM FIX jQuery.get('/netapp', {vid :<%= vid %>}, function(data) {	
		jQuery.get('/netapp', {vid : "7"}, function(data) {	
			d = jQuery.parseJSON(data)
			if(d) {
				$.each(d, function(i, v) {
					res2+="<option value=\"" + v.requestid + "\">" + v.requestid
					res2+="</option>"
				})
			}
			res2+="</select>"
			$('.apps-single').html(res + res2 + "<input type=\"submit\" value=\"run\"/></form>");						
		})
	});
}

function get_info(n) {
	jQuery.get('/netapp/id/'.concat(n.data.id),{}, function(data) {				
		$('.result').html(data)
		d = jQuery.parseJSON(data)
		if(d) {
			if(d.status == "done") {
				n.data.pending = "done"
			}
		}
	});
}

function get_info_edge(node, point) {
	var edg = $.merge(sys.getEdgesFrom(node), sys.getEdgesTo(node))
  console.log(edg)
	var ppp = sys.fromScreen(point)
	var e = select_edge(edg, ppp.x, ppp.y)
  console.log(e)			
	//MXM FIX jQuery.get('/netapp/link/tuple/' + e.source.name + ':' + e.target.name,{vid :<%= vid %>}, function(data) {				
	jQuery.get('/netapp/link/tuple/' + e.source.name + ':' + e.target.name,{vid : "7" }, function(data) {				
		$('.result').html(data)
	});
}


function make_tunnel(src, dst) {
	// MXM FIX jQuery.post('/netapp/link', {"src" : src.data.id, "dst" : dst.data.id, "vid" : "<%= vid %>"}, function(data) {		
	jQuery.post('/netapp/link', {"src" : src.data.id, "dst" : dst.data.id, "vid" : "1" }, function(data) {		
		$('.result').html(data);
		sys.addEdge(src, dst, {pending:"pending"})			  
		sys.numedges+=1
		// This should be called when state changes... use callback
    //				get_netapps()
	});
}

function create_new_node() {		
  $('.result').html("using zone: " + $("input[@name=z]:checked").val())
			// MXM FIX jQuery.post('/netapp', {"filter" : {"zones" : $("input[@name=z]:checked").val()}, "vid" : "<%= vid %>", "name" : "testing"}, function(data) {
  jQuery.post('/netapp', {"filter" : {"zones" : $("input[@name=z]:checked").val()}, "vid" : "1", "name" : "testing"}, function(data) {
    $('.result').html(data)
    sys.addNode(data, {id:data, alone:true, mass:.25, pending: "pending"})
    sys.numnodes+=1
				// This should be called when state changes... use callback
//				get_netapps()
    })
}


            // MXM: mod 
function create_new_node2() {		
                  // MXM: writing to .result div class 
                  //			$('.result').html("using zone: " + $("input[@name=z]:checked").val())
  console.log("Adding node in : " +  $('[name=zones_select]').val());
  console.log("Adding node in : " +  $('[name=number_of_instances]').val());
  var num = $('[name=number_of_instances]').val();

  for (var i = 0; i <  Number(num) ; i++){
    console.log("adding number " + i);
    // MXM FIX jQuery.post('/netapp', {"filter" : {"zones" : $('[name=zones_select]').val()}, "vid" : "<%= vid %>", "name" : "testing"}, function(data) {
    jQuery.post('/netapp', {"filter" : {"zones" : $('[name=zones_select]').val()}, "vid" : "1", "name" : "testing"}, function(data) {
			   $('.result').html(data);
			   sys.addNode(data, {id:data, alone:true, mass:.25, pending: "pending"});
			   sys.numnodes+=1;
				// This should be called when state changes... use callback
         get_netapps();
         console.log(sys); 
     })
  }
}

function delete_node(node) {
	// delete the node
	$.ajax({
 		type: 'DELETE',
 		url: "/netapp/id/".concat(node.data.id),
 // MXM FIX 		data: "vid=<%= vid %>",
 		data: "vid=1",
 		dataType: 'text'
 	}).done(function(result) { 
	  $('.result').html(result)
		sys.numnodes-=1				
	})
}

(function($){
  Renderer = function(canvas){
    var canvas = $(canvas).get(0)
    var ctx = canvas.getContext("2d");
    var particleSystem;

    var that = {
      init:function(system){
				sys.numnodes = 0
				sys.numedges = 0
        particleSystem = system
        particleSystem.screenSize(canvas.width, canvas.height) 
        particleSystem.screenPadding(80)		        		
				that.initMouseHandling()
      },

      redraw:function(){
				if(mode=="draw") particleSystem.stop()

        ctx.fillStyle = "white"
        ctx.fillRect(0,0, canvas.width, canvas.height)

				if (mode == "draw") {
					if(sys.srcA != null) { // Waarom is src null?

						var mys = particleSystem.toScreen(sys.srcA.node.p)
						var myd = particleSystem.toScreen(particleSystem.fromScreen(sys.dstA))

						$('.result').html("adding edge:".concat(sys.srcA.data))
						ctx.strokeStyle = "rgba(0,0,0, .333)"
					  ctx.lineWidth = 20
						ctx.beginPath();
					  ctx.moveTo(mys.x, mys.y);
						ctx.lineTo(myd.x, myd.y);
					  ctx.stroke();								
					}
				}
										
        particleSystem.eachEdge(function(edge, pt1, pt2){
          // edge: {source:Node, target:Node, length:#, data:{}}
          // pt1:  {x:#, y:#}  source position in screen coords
          // pt2:  {x:#, y:#}  target position in screen coords

          // draw a line from pt1 to pt2
					if(edge.data.pending != "done") {
						ctx.strokeStyle = "rgba(0.5,0.4,0.2, .333)"
          	ctx.lineWidth = 1
					} else {
						ctx.strokeStyle = "rgba(0,0,0, .555)"
          	ctx.lineWidth = 5								
					}
        	ctx.beginPath()
          ctx.moveTo(pt1.x, pt1.y)
          ctx.lineTo(pt2.x, pt2.y)
          ctx.stroke()
        })

        particleSystem.eachNode(function(node, pt){
          // node: {mass:#, p:{x,y}, name:"", data:{}}
          // pt:   {x:#, y:#}  node position in screen coords
					if(!node.data.invisible) {
						if(node.data.pending != "done") {
							ctx.fillStyle = "gray"
				  		ctx.font = "20pt Arial";									
						} else {
							ctx.fillStyle = "black"
				  		ctx.font = "Bold 20pt Arial";									
						}
			  		ctx.fillText(node.name, pt.x, pt.y)
						if(showinfo == true) {
							if(showinfo_node == node) {
			  				ctx.fillText(node.data.id, pt.x, pt.y+25)
							}
		  			}
					}
        }) 		   			
      },

      initMouseHandling:function(){
        // no-nonsense drag and drop (thanks springy.js)
        var dragged = null;

        var handler = {
          clicked:function(e){
            var pos = $(canvas).offset();
            _mouseP = arbor.Point(e.pageX-pos.left, e.pageY-pos.top)
            dragged = particleSystem.nearest(_mouseP);

            if (dragged && dragged.node !== null){
              // while we're dragging, don't let physics move the node
              dragged.node.fixed = true
            }


						switch(mode) {
							case "draw":
								sys.srcA = dragged;
								sys.dstA = _mouseP;
								particleSystem.stop();
								break;
							case "info":
								showinfo = true;
								get_info(dragged.node); // XXX: Blocking?
								showinfo_node = dragged.node;	
								particleSystem.start();									
								break;
							case "info_edge":
								get_info_edge(dragged.node, _mouseP); // XXX: Blocking?
								particleSystem.start();									
								break;
							case "del_node":
								delete_node(dragged.node);
								break;										
							case "del_edge":
							// XXX: This is optimized. Selects the edges connected to
							//   the nearest node and calculated distance to those 
							//   nodes.
							// 									
								var edg = $.merge(sys.getEdgesFrom(dragged.node), sys.getEdgesTo(dragged.node))
								var ppp = particleSystem.fromScreen(_mouseP)
								delete_edge(edg, ppp);
								break;										
						}

            $(canvas).bind('mousemove', handler.dragged)
            $(window).bind('mouseup', handler.dropped)
						
            return false
          },
          dragged:function(e){
            var pos = $(canvas).offset();
            var s = arbor.Point(e.pageX-pos.left, e.pageY-pos.top)

            if (dragged && dragged.node !== null){
              var p = particleSystem.fromScreen(s)

             	if(mode=="info") {
								dragged.node.p = p
							} else {
								particleSystem.stop()										
							}
            }								

						sys.dstA = s
						that.redraw();
          	return false
          },
          dropped:function(e){
            if (dragged===null || dragged.node===undefined) return
            if (dragged.node !== null) dragged.node.fixed = false

            var pos = $(canvas).offset();
            var s = arbor.Point(e.pageX-pos.left, e.pageY-pos.top)

						sys.srcA = dragged
						sys.dstA = s

            dragged.node.tempMass = 1000
            dragged = null
            $(canvas).unbind('mousemove', handler.dragged)
            $(window).unbind('mouseup', handler.dropped)
            _mouseP = null

						if(mode =="draw"){
							//flipmode();									
							var na = particleSystem.nearest(sys.dstA).node
							if(na.data.invisible != true && sys.srcA.node.data.invisible != true) {
								make_tunnel(sys.srcA.node, na);
							}
							particleSystem.start();
							sys.srcA = null
							sys.dstA = null								
					  } else {
							showinfo = false
							showinfo_node = null								
						}	
            return false
          }
        }
        // start listening
        $(canvas).mousedown(handler.clicked);
      },
    }
    return that
  }    

$(document).ready(function(){
  console.log("Calling ");
	sys = arbor.ParticleSystem(500, 100, 0.5);
  sys.parameters({gravity:true});
  sys.renderer = Renderer("#viewport");
  sys.start(); 

  sys.addNode('Test',{invisible:true, mass:.25});
  console.log(sys);
  console.log("Adding Node"); 

 	get_netapps()
 	
  get_locations()

 	get_locations_option_list()
 	
 	get_apps()
 	
 	get_apps_single(sys)
 					
 	// Bind functions to the UI
 	$('div.mode_info').click(function(){
 		flipmode("info");
 	});

 	$('div.mode_info_edge').click(function(){
 		flipmode("info_edge");
 	});

 	$('div.mode_draw').click(function(){
 		flipmode("draw");
 	});

 	$('div.mode_del_node').click(function(){
 		flipmode("del_node");
 	});				

 	$('div.mode_del_edge').click(function(){
 		flipmode("del_edge");
 	});				
 	
 	$('div.create_node').click(function(){
 //		create_new_node()
  });				

 	$('div.create_node2').click(function(){
 	//	create_new_node2()
      restart();
      addnode(1,1,2); 
      restart();
   });				

 	
 	$('div.apps').click(function(){
 		run_app()
 	});
 	
 	// setup an event feed, so we don't have to poll				
 	var eventSrc  = new EventSource("/netapp/feed?vid=7");

   eventSrc.addEventListener('message', function (event) {
		console.log("eveeeeeent: " + event.data)
 		// for now events just trigger updating
 		if(event.data != "pong!") {
 			get_netapps()
 	  }
   	});				

 	flipmode("info");
	get_netapps()
 })
})(this.jQuery);

