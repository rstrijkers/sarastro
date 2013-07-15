

// Post Method! 
$(document).ready(function() { 
   // bind 'myForm' and provide a simple callback function 
   $('#myForm').ajaxForm(function() { 
                var url = $url("http://netapp.strijkers.eu:64091/CD/bla.txt");
                console.log(url); 
                alert("Thank you for your comment!"); 
          }); 
   }); 




