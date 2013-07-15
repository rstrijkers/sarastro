var width = screen.width,
    height = screen.height,
    fill = d3.scale.category10(),
    nodes = [];
var links = [];
var nodeSize = 8;
var mode = "info"; //0 =  remove , 1 = add;
var selectedNode = new Object(); 
var zones = {};
selectedNode.node = null; 

console.log("Loaded"); 


zones["eu-west-1a"] = 0;
zones["eu-west-1b"] = 1;
zones["eu-west-1c"] = 2;


function resolveZone(zoneName)
{
//  return zones[zoneName];
	return zoneName;
}



// add node to global pool of nodes. 
function addnode(id, vid, zone)
{
  var num = $('[name=number_of_instances]').val();
  var zone = resolveZone($('[name=zones_select]').val()); 
  console.log(nodes); 
   for ( var i = 0; i < Number(num); i++)
    { 
        $.post('/netapp', { "filter" : {"zones" : zone}, "vid" : "1" , "name" : "testing"}, function(data) 
        {
          console.log( $('.result').html(data));

        });
        var node = {x:1920, y: 1080};
        node.vi = zone
        node.id = num;
        n = nodes.push(node);
        console.log("Adding nodes in:" + zone) ;
    }
}

function addlink(d)
{
   links.push({source: selectedNode.node, target: d});
}

function getnode(color, vid, zone)
{
  var node = { x : screen.width, y: screen.heigth } ;
  node.vi = zone; 
  return node; 
}


var vis = d3.select("#chart").append("svg")
    .attr("width", width)
    .attr("height", height);


var force = d3.layout.force()
    .distance(1500) 
    .nodes(nodes)
    .links([])
    .size([width, height]);


vis.style("opacity", 1e-6)
  .transition()
  .duration(100)
  .style("opacity", 1);


force.on("tick", function(e) {
  // Push different nodes in different directions for clustering.
    var k = 6 * e.alpha;
    vis.selectAll("line.link")
      .attr("x1", function(d) { return d.source.x; })
      .attr("y1", function(d) { return d.source.y; })
      .attr("x2", function(d) { return d.target.x; })
      .attr("y2", function(d) { return d.target.y; });


    nodes.forEach(function(o, i) {
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
  
  vis.selectAll("circle.node")
      .attr("cx", function(d) { return d.x; })
      .attr("cy", function(d) { return d.y; });
});



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





function resetLayout() {
d3.select("body").on("click", function() {
  nodes.forEach(function(o, i) {
    o.x += (Math.random() - .5) * 40;
    o.y += (Math.random() - .5) * 40;
  });
  force.resume();
  }); 
}

function restart(){
  force.start();
  
 vis.selectAll("line.link")
      .data(links)
      .enter().insert("svg:line", "circle.node")
      .attr("class", "link")
      .attr("r", 4)
      .attr("x1", function(d) { return d.source.x; })
      .attr("y1", function(d) { return d.source.y; })
      .attr("x2", function(d) { return d.target.x; })
      .attr("y2", function(d) { return d.target.y; });

  vis.selectAll("circle.node")
      .style("fill", "steelblue")
      .data(nodes)
      .attr("text-anchor", "middle")
      .enter().insert("circle", "circle.cursor")
      .attr("class", "node")
      .attr("cx", function(d) { return d.x; })
      .attr("cy", function(d) { return d.y; })
      .attr("r", nodeSize)
      .call(force.drag)
      .on("click", function(d) {
          console.log("mode : " + mode); 
          switch(mode){
            case "del_node": // delete node 
              console.log(d); 
              console.log(nodes.length); 
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

                nodes.splice (d, 1);
                d3.select(this).remove(); 


              break; 

              case "info":
                if(selectedNode.node == null) {
                    selectedNode.node = d; 
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
                    if ( selectedNode.id != d)  { 
                    d3.select(selectedNode.id).attr("r", nodeSize);
                    //              links.push({source: selectedNode.node, target: d});

                    addlink(d); 
                    selectedNode.node = null; 
                      } 
                  }
              case 3:

                restart();

              console.log(links); 
                break;


            default:
            break; 
            }
      });
      
      

  console.log(links.length); 
}

restart(); 
