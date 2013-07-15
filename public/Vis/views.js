


var viewMaps = 0;


var lastvisible = null;




function showMap(target)
{
      console.log(target);
      if ( target != lastvisible) 
      {
         $(lastvisible).hide("fast");
         $(target).show("fast");
         lastvisible = target;

      } 
}

function hideMap(target)
{
   $(target).hide("fast");
}
   
