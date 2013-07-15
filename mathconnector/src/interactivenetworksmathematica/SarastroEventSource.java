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
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.SocketTimeoutException;
import java.net.URL;
import java.util.Observable;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 *
 * @author rudolf
 */
public class SarastroEventSource extends Observable implements Runnable {
    private String _feed;
    private String _links;    
    private Thread t;
    private static KernelLink _ml;
    
    public SarastroEventSource(String feed, String links) {
        _feed = feed;
        _links = links;                
    }
    
    public void start() {
        _ml = StdLink.getLink();
        this.addObserver(new TopologyHandler(_ml, _links));
        
        t = new Thread(this); // THIS IS AN ISSUE, CANNOT Catch the exception

        t.start();
    }
    
    public void stop() {
        // break out the blocking socket read
        t.interrupt();        
    }
   
    public static void onLoadClass(KernelLink ml) throws MathLinkException {
        System.out.println("im loaded");
    }
   
    public void run() {       
        BufferedReader in = null;
        try {
            URL httpEvent = new URL(_feed);
            in = new BufferedReader(
                    new InputStreamReader(httpEvent.openStream()));            
            
            while(true) {
                String event;

                try {
                    System.out.println("waiting for new event");
                    
                    event = in.readLine();

                    if(event == null) {
                       System.out.println("Other end closed connection.");
                       break;
                    }
                
                    System.out.println("Got event: " + event);
                    
                    setChanged();
                    notifyObservers(event);   
                } catch (SocketTimeoutException e) {
                    System.out.println("Timeout, continuing...");
                    continue;
                }               
            }
            
            System.out.println("Event stream closed connection.");
            in.close();
        } catch (IOException ex) {
            Logger.getLogger(SarastroEventSource.class.getName()).log(Level.SEVERE, null, ex);
        } finally {
            System.out.println("Stopping!");
            try {
                in.close();
            } catch (IOException ex) {
                Logger.getLogger(SarastroEventSource.class.getName()).log(Level.SEVERE, null, ex);
            }
        }
    }
}
