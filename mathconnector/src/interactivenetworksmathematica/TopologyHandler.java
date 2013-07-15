/*
 * Copyright (C) 2012 Rudolf Strijkers <rudolf.strijkers@tno.nl>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
package interactivenetworksmathematica;

import com.wolfram.jlink.KernelLink;
import com.wolfram.jlink.MathLinkException;
import com.wolfram.jlink.StdLink;
import java.io.IOException;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.ArrayList;
import java.util.List;
import java.util.Observable;
import java.util.Observer;
import java.util.logging.Level;
import java.util.logging.Logger;
import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.fluent.Request;

/**
 *
 * @author rudolf
 */
public class TopologyHandler implements Observer {
    KernelLink _ml = null;
    URL _links = null;
    
    public TopologyHandler(KernelLink ml, String links) {
        _ml = ml;
        
        try {
            _links = new URL(links);
        } catch (MalformedURLException ex) {
            Logger.getLogger(TopologyHandler.class.getName()).log(Level.SEVERE, null, ex);
        }
    }
    
    public void update(Observable o, Object arg) {
        String resp;
        
        if(arg instanceof String) {
            resp = (String) arg;
            System.out.println("Got event: " + resp);
            
            getLinks();
        }
    }
    
    public void getLinks() {
        // retrieve links from sarastro
        List links = parseLinks(getStringFromURL(_links));
        
        System.out.println("got links: " + links);
        
        // XXX: process links to from e1 <-> e2, ...        
        mathEvaluateGraph(links);      
    }
    
    public static void onLoadClass(KernelLink ml) throws MathLinkException {
        System.out.println("im loaded");
    }

    public void mathEvaluateGraph(List<String []> links) {        
        _ml = StdLink.getLink();

        try {
            _ml.beginManual();
            System.out.println("0");
            _ml.putFunction("Set", 2);
            System.out.println("1");
            
            _ml.putSymbol("network");
            //System.out.println("2");
            _ml.putFunction("Graph", 1);
                _ml.putFunction("List", links.size());
                for(String [] edge : links) {                
                    _ml.putFunction("UndirectedEdge", 2);
                    _ml.put(edge[0]);
                    _ml.put(edge[1]);
                }
            
            //_ml.put(expr);
            //System.out.println("3");
            _ml.discardAnswer();            
            System.out.println("4");
        } catch (MathLinkException e1) {
            System.out.println("error reading mathematica packet" + e1);
            _ml.clearError();
            _ml.newPacket();
        }
    }

    public String getStringFromURL(URL url) {
        try {
            System.out.print("getting url: " + url.toString());
            return Request.Get(url.toString()).execute().returnContent().toString();
        } catch (ClientProtocolException ex) {
            Logger.getLogger(TopologyHandler.class.getName()).log(Level.SEVERE, null, ex);
        } catch (IOException ex) {
            Logger.getLogger(TopologyHandler.class.getName()).log(Level.SEVERE, null, ex);
        }             
        
        return "";
    }
    
    public List parseLinks(String links) {
        List edges = new ArrayList();

        if(links == null) {
            return edges;
        }
        
        String [] l = links.split("\\{\"job\":\"create_link\"");
    
        for(int i = 0; i < l.length; i++) {
            String [] l2 = l[i].split("status")[0].split("\"");
            if(l2.length > 15) {
                edges.add(new String [] {l2[11], l2[15]});
            }
        }
        
        return edges;
    }
}
