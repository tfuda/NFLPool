public class GameSelection {

	public Integer gameNumber { get; set; }
    public Game__c game { get; set; }
    public Selection__c selection { get; set; }
    public String playerId { get; set; }
    
    public Boolean isLocked { 
    	get {
    		Game__c current = [select start_time__c from game__c where id=:game.id limit 1];
    		return (Datetime.now() > current.start_time__c);
    	}
    }
    
    public Boolean hSelect { 
    	get {
    		if (hSelect == null) {
    			hSelect = false;
    		}
    		return hSelect;
    	}
    	set; 
    }
    
    public Boolean vSelect { 
    	get {
    		if (vSelect == null) {
    			vSelect = false;
    		}
    		return vSelect;
    	}
    	set; 
    }
        
    public Boolean isDirty { 
    	get {
   			isDirty = false;
    		if (selection != null) {
	  			isDirty = !(selectedTeam == selection.Team__c);
    		} else {
    			if (selectedTeam != null) {
    				isDirty = true;
    			}
    		}
    		return isDirty;
    	}
    	set;
    }
    
    public String selectedTeam { 
    	get {
	        if (true == hSelect) {
	            return game.Home_Team__c;
	        } else if (true == vSelect) {
	            return game.Visiting_Team__c;
	        } else {
	        	return null;
	        }
    	}
    }
 
    public GameSelection(Integer gameNumber, String playerId, Game__c game, Selection__c selection) {   
        this.gameNumber = gameNumber;
        this.playerId = playerId;
        this.game = game;
        this.selection = selection;
	    if (selection != null) {
    		// Set the hSelect or vSelect flags
    		if (selection.team__c == game.home_team__c) {
    			this.hSelect = true;
    			this.vSelect = false;
    		} else if (selection.team__c == game.visiting_team__c) {
    			this.vSelect = true;
    			this.hselect = false;
    		}
       	} else {
       		this.hSelect = false;
       		this.vSelect = false;
	    }
    }
    
    /**
     * Saves this game selection. By contract, this method should only be called when
     * there are unsaved changes, i.e. the GameSelection "is dirty".
     */
    public void save(Boolean isAdmin) {
        // Only try to save the game if it is not locked or if we are the admin        
        if (!(isLocked) || (isAdmin)) {
		    
            // First, create a new Selection object if necessary
            if (selection == null) {
            	try {
	            	// See if there's an existing selection
	            	Selection__c existingSelection = [Select s.Id, s.Name, s.Game__c, s.Player__c, s.Team__c 
	            		From Selection__c s Where s.Game__c = :game.Id and s.Player__c = :playerId limit 1];
	            		
	            	// A selection, we'll just update it
	            	selection = existingSelection;
	            		
            	} catch (QueryException qe) {
            		 
            		// No selection exists yet, so create one 
	                selection = new Selection__c();
					selection.game__c = game.Id;
					selection.player__c = playerId;                	                
            	}
            }            
     
            // Set the selected team based on which checkbox is selected
            selection.Team__c = selectedTeam;
            upsert selection;
            
        // Can't save the game because it is locked    
        } else {
            throw new SaveException('Unable to save selection because the game is locked');
        }
    }
}