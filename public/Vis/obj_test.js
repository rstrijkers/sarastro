

var nodePlane = new Object();
nodePlane.width = screen.width; 
nodePlane.height = screen.height; 
nodePlane.nodes = [];
nodePlane.links = [];
nodePlane.nodeSize = 8; 
nodePlane.fill = d3.scale.category10();
nodePlane.zones = {};
nodePlane.selectedNode = null

nodePlane.init = function() {
  this.loadZones(); 

  this.vis = d3.select("#chart").append("svg")
    .attr("width", this.width)
    .attr("height", this.height);


  this.vis.style("opacity", 1e-6)
    .transition()
    .duration(100)
    .style("opacity", 1);


  this.force = d3.layout.force()
    .distance(1500) 
    .nodes(this.nodes)
    .links([])  // Do not use force on links.
    .size([this.width, this.height]);

  this.force.on("tick", function(e) {
  // Push different nodes in different directions for clustering.
    var k = 6 * e.alpha;
    nodePlane.vis.selectAll("line.link")
      .attr("x1", function(d) { return d.source.x; })
      .attr("y1", function(d) { return d.source.y; })
      .attr("x2", function(d) { return d.target.x; })
      .attr("y2", function(d) { return d.target.y; });


    nodePlane.nodes.forEach(function(o, i) {
      switch(o.vi) 
      {
        case 0:
          o.x += -10*k; 
          o.y += k;
          break;

        case 1:
          o.x += -13*k; 
          o.y += k;
          break;
        case 2:
          o.x += -14*k; 
          o.y += -5 *k; 
          break; 
        case 3:
          o.x += -14*k; 
          o.y += -5 *k; 
          break;
        case 4:

          break;
        case 5:

          break;
        case 6:


        default:
          o.x += i & 2 ? k : -k;
          o.y += i & 1 ? k : -k;
        }
    });
  
    nodePlane.vis.selectAll("circle.node")
      .attr("cx", function(d) { return d.x; })
      .attr("cy", function(d) { return d.y; });
  });
  this.restart(this);  

};

nodePlane.loadZones = function() {
  this.zones["eu-west-1a"] = 0;
  this.zones["eu-west-1b"] = 1;
  this.zones["eu-west-1c"] = 2;
};

nodePlane.resolveZone = function(zoneName) {
  return this.zones[zoneName];
};


nodePlane.addNode = function(id, num, zone) {

  //var num = $('[name=number_of_instances]').val();
 // var zone = resolveZone($('[name=zones_select]').val()); 
 //
  for ( var i = 0; i < Number(num); i++)
  { 
//        $.post('/netapp', { "filter" : {"zones" : zone}, "vid" : "1" , "name" : "testing"}, function(data) 
//        {
//          console.log( $('.result').html(data));
//
//        });
     var node = {x:102, y: 102};
     console.log(node); 
     node.vi = zone;
     node.id = num;
     n = this.nodes.push(node);
     console.log(this.nodes); 
     console.log("Adding nodes in:" + zone) ;
  }
}

nodePlane.addLink = function(d)
{
   this.links.push({source: this.selectedNode.node, target: d});
}


nodePlane.resetLayout = function () {
  d3.select("body").on("click", function() {
  this.nodes.forEach(function(o, i) {
    o.x += (Math.random() - .5) * 40;
    o.y += (Math.random() - .5) * 40;
  });
  this.force.resume();
  }); 
}









nodePlane.restart = function(NP){
 NP.force.start();
  
 NP.vis.selectAll("line.link")
      .data(NP.links)
      .enter().insert("svg:line", "circle.node")
      .attr("class", "link")
      .attr("x1", function(d) { return d.source.x; })
      .attr("y1", function(d) { return d.source.y; })
      .attr("x2", function(d) { return d.target.x; })
      .attr("y2", function(d) { return d.target.y; });

  NP.vis.selectAll("circle.node")
      .style("fill", "steelblue")
      .data(NP.nodes)
      .attr("text-anchor", "middle")
      .enter().insert("circle", "circle.cursor")
      .attr("class", "node")
      .attr("cx", function(d) { return d.x; })
      .attr("cy", function(d) { return d.y; })
      .attr("r", NP.nodeSize)
      .call(NP.force.drag)
      .on("click", function(d) {
          console.log("mode : " + NP.mode); 
          switch(NP.mode){
            case "del_node": // delete node 
              console.log(d); 
              console.log(NP.nodes.length); 
// MXM Ajax call create. 
//	            $.ajax({
// 		            type: 'DELETE',
// 		            url: "/netapp/id/".concat(node.data.id),
// 		            data: "vid=1",
// 		            dataType: 'text'
// 	            }).done(function(result) { 
//	              $('.result').html(result)
//		            sys.numnodes-=1				
//	            });

                NP.nodes.splice (d, 1);
                d3.select(this).remove(); 

              break; 

              case "info":
                if(NP.selectedNode.node == null) {
                    NP.selectedNode.node = d; 
                    selectedNode.id = this; 
                    d3.select(this)
                      .transition()
                      .duration(750)
                      .attr("r", 2* nodeSize);
                    force.stop()
                  } else {
                    console.log(selectedNode.node); 
                    console.log(d); 
                    d3.select(this)
                      .transition()
                      .duration(500)
                      .attr("r", 2*nodeSize)
                      .duration(500)
                      .attr("r", nodeSize); 
                    if ( NP.selectedNode.id != d)  { 
                      d3.select(selectedNode.id).attr("r", nodeSize);
                    //              links.push({source: selectedNode.node, target: d});

                      NP.addlink(d); 
                      NP.selectedNode.node = null; 
                    } 
                  }
              case 3:
                NP.restart(this);

                console.log(NP.links); 
                break;


            default:
            break; 
            }
      });
      
      

  console.log(NP.links.length); 
}

nodePlane.init();
nodePlane.restart(nodePlane); 

for( var i = 0; i < 10; i++)
{
  nodePlane.addNode(i, i, i % 3); 

}

// END

//var width = screen.width,
//    height = screen.height,
//    fill = d3.scale.category10(),
//    nodes = [];
//var links = [];
//var nodeSize = 8;
//var mode = "info"; //0 =  remove , 1 = add;
//var selectedNode = new Object(); 
//var zones = {};
//selectedNode.node = null; 
//
//console.log("Loaded"); 
//
//
//function resolveZone(zoneName)
//{
//  return zones[zoneName];
//}
//
//
//
//// add node to global pool of nodes. 
//function addnode(id, vid, zone)
//{
//}
//
//
//function addlink(d)
//{
//   links.push({source: selectedNode.node, target: d});
//}
//
//var vis = d3.select("#chart").append("svg")
//    .attr("width", width)
//    .attr("height", height);
//
//
//var force = d3.layout.force()
//    .distance(1500) 
//    .nodes(nodes)
//    .links([])
//    .size([width, height]);
//
//
//vis.style("opacity", 1e-6)
//  .transition()
//  .duration(100)
//  .style("opacity", 1);
//
//
//function getnode(color, vid, zone)
//{
//  var node = { x : screen.width, y: screen.heigth } ;
//  node.vi = zone; 
//  return node; 
//}
//
//for ( var i = 0; i < 10;i++ ) {
//  addnode(i, 0, i & 3)
//}
//
//force.on("tick", function(e) {
//  // Push different nodes in different directions for clustering.
//    var k = 6 * e.alpha;
//    vis.selectAll("line.link")
//      .attr("x1", function(d) { return d.source.x; })
//      .attr("y1", function(d) { return d.source.y; })
//      .attr("x2", function(d) { return d.target.x; })
//      .attr("y2", function(d) { return d.target.y; });
//
//
//    nodes.forEach(function(o, i) {
//      switch(o.vi) 
//      {
//        case 0:
//          o.x += -10*k; 
//          o.y += k;
//          break;
//
//        case 1:
//          o.x += -13*k; 
//          o.y += k;
//          break;
//        case 2:
//          o.x += -14*k; 
//          o.y += -5 *k; 
//          break; 
//        case 3:
//          o.x += -14*k; 
//          o.y += -5 *k; 
//          break;
//        case 4:
//
//          break;
//        case 5:
//
//
//          break;
//        case 6:
//
//
//        default:
//          o.x += i & 2 ? k : -k;
//          o.y += i & 1 ? k : -k;
//      }
//  });
//  
//  vis.selectAll("circle.node")
//      .attr("cx", function(d) { return d.x; })
//      .attr("cy", function(d) { return d.y; });
//});
//
//function resetLayout() {
//d3.select("body").on("click", function() {
//  nodes.forEach(function(o, i) {
//    o.x += (Math.random() - .5) * 40;
//    o.y += (Math.random() - .5) * 40;
//  });
//  force.resume();
//  }); 
//}
//
//
//
//d3.selectAll("circle.node").on("click", function(d) {
//    console.log("mode : " + mode); 
//    switch(mode){
//      case 0: // delete node 
//        console.log(this); 
//      // remove node from array . 
//
//        d3.select(this).remove(); 
//
//      case 1: // addnode 
//      break; 
//
//      default:
//      break; 
//      }
//      });


//gvis.on("mousedown", function(d) {
//g    force.stop(); 
//g    console.log("mode : " + mode); 
//g    switch(mode) {
//g    case 0:
//g        // remove node
//g//        console.log(d.vi); 
//g//        d3.select(this).remove();
//g        break; 
//g      // add node. 
//g    case 1:
//g        console.log("adding node: ", nodes.length);
//g        addnode(0,0,nodes.length % 3);
//g        console.log("new total: ", nodes.length);
//g        break; 
//g
//g      default:
//g      break
//g   }
//g  restart(); 
//g
//g  });






//function redraw() {
//node = vis.selectAll("circle.node").data(nodes)
//  node
//    .enter()
//      .append("circle")
//      .attr("class", "node")
//      .attr("cx", function(d) { return width/2; })
//      .attr("cy", function(d) { return height/2; })
//      .attr("r", 5)
//      .on("click", function(d) { alert(d.vi)})
//}
