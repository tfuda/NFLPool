global class PlayerController {

    public static String MODE_EDIT = 'edit';
    public static String MODE_NEW = 'new';
    public static String MODE_VIEW = 'view';
    
    public Boolean underTest { get; set; }
        
    public PlayerWrapper wrapper { get; set; }
    public List<PaymentWrapper> pmtWrappers { get; set; }
    public String id { get; set; }
    public String mode { get; set; }
    
    public Boolean editingPayment { 
        get {
            if (editingPayment == null) {
                editingPayment = false;
            }
            return editingPayment;
        }
        set; 
    }
    
    /* For profile select list */
    public List<SelectOption> profileOptions { 
        get {
            if (profileOptions == null) {
                profileOptions = new List<SelectOption>();
                // Get profiles
                List<Profile> profiles = 
                    [select id, name from profile where name = 'Player' or name = 'Pool Administrator'];
                for (Profile pro : profiles) {
                    profileOptions.add(new SelectOption(pro.id, pro.name));                 
                }
            }
            return profileOptions;
        }
        set;
    }    
    
    /* The Salesforce Server URL */
    public String serverUrl {
        get {
            return ApexPages.currentPage().getParameters().get('serverUrl');
        }
    }

    /* URL to use as the web service endpoint. You must append the '/class/<packagename>/<classname>' to it. */
    public String webServiceUrl {
        get {
            Pattern serverUrlPattern = Pattern.compile('(https://.*?/services/Soap).*?');
            Matcher serverUrlMatcher = serverUrlPattern.matcher(serverUrl);
            if (serverUrlMatcher.matches()) {
                return serverUrlMatcher.group(1);
            } else {
                return null;
            }         
        }
    }
    
    /* Salesforce server name. For example: na6.salesforce.com */
    public String serverName {
        get {
            Pattern serverUrlPattern = Pattern.compile('https://(.*?)/.*?');
            Matcher serverUrlMatcher = serverUrlPattern.matcher(serverUrl);
            if (serverUrlMatcher.matches()) {
                return serverUrlMatcher.group(1);
            } else {
                return null;
            }       
        }
    }

    public Settings__c settings {
        get {
            return PoolManagerUtils.getSettings();
        }
    }
    
    public PlayerController() {
        id = ApexPages.currentPage().getParameters().get('id');
        mode = ApexPages.currentPage().getParameters().get('mode');
        if (id != null) {
            
            // Get the player details
            refreshPlayerDetails(id);
            
        // If no ID is provided
        } else {
            // Check the mode. If 'new', were creating a new player
            if (MODE_NEW.equalsIgnoreCase(mode)) {
                // Instantiate a new user object
                wrapper = new PlayerWrapper();
                wrapper.usr = new User();
                
                // Suggest a username and default to active
                wrapper.usr.username = '<first.last>@' + settings.usernamesuffix__c;
                wrapper.usr.isactive = true;
                
            // Default to the currently logged in user ID
            } else {
                id = UserInfo.getUserId();
                mode = MODE_VIEW;
                refreshPlayerDetails(id);               
            }
        }       
    }
    
    /* Retrieves the PlayerWrapper (User, Player) and PaymentWrapper list for the specified User */
    @TestVisible private void refreshPlayerDetails(String userId) {
        wrapper = PlayerWrapper.getPlayerWrapper(userId);
        pmtWrappers = new List<PaymentWrapper>(); 
        for (Integer i=0; i < wrapper.player.payments__r.size(); i++) {
            pmtWrappers.add(new PaymentWrapper(i, wrapper.player.payments__r.get(i), MODE_VIEW));
        }
    }
    
    public PageReference edit() {
        mode = MODE_EDIT;
        return null;        
    }
    
    public PageReference save() {
        if (MODE_NEW.equals(mode)) {
            // This creates the Player and User records for the player in one operation
            try {
                createPlayer();
                
                // Display success message to VF page
                ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.INFO, 
                    'Successfully created new Player with username: ' + wrapper.usr.username);
                ApexPages.addMessage(msg);
                
            } catch (Exception e) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                    'Unable to create player. Underlying error was: ' + e.getMessage()));
                return null;                
            }
            
        } else {
            try {
                updatePlayer();
            
                // Display success message to VF page
                ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.INFO, 
                    'Successfully updated Player with username: ' + wrapper.usr.username);
                ApexPages.addMessage(msg);
                
            } catch (Exception e) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                    'Unable to update player. Underlying error was: ' + e.getMessage()));
                return null;                                
            }           
        }
        mode = MODE_VIEW;
        return null;
    }
    
    public PageReference cancel() {
        // If we were editing an existing player
        if (id != null) {
            // Refresh the original PlayerWrapper object and PaymentWrapper list
            refreshPlayerDetails(id);
            mode = MODE_VIEW;
            return null;
        // If we were creating a new player
        } else {
            // Return to player management page
            return Page.PlayerManagement;
        }
    }
        
    /*
     * This does the work of creating a new player. It first creates a User for the player. It
     * does this as a web service so that it is an atomic transaction. If successful, then we create
     * a Player object for the player and associate the User and Player object.
     */
    @TestVisible private void createPlayer() {       
        String userId;
        try {
            System.debug('Creating User: ' + wrapper.usr);
                        
            SoapUtils.PoolManagerUtils soap = new SoapUtils.PoolManagerUtils();
            
            // Determine the endpoing dynamically
            soap.endpoint_x = webServiceUrl + '/class/PoolManagerUtils';          
            System.debug('Soap Endpoint = ' + soap.endpoint_x);
                 
            soap.SessionHeader = new SoapUtils.SessionHeader_element();           
            soap.SessionHeader.sessionId = UserInfo.getSessionId();           
            System.debug('Session ID: ' + UserInfo.getSessionId());
            
            // Create the User
            if (true != underTest) {
                userId = soap.createPlayerUser(wrapper.usr.firstname, 
                    wrapper.usr.lastname, wrapper.usr.username, 
                    wrapper.usr.communitynickname, wrapper.usr.email, 
                    wrapper.usr.phone, wrapper.usr.street, wrapper.usr.city,
                    wrapper.usr.state, wrapper.usr.postalcode,
                    wrapper.usr.profileid, wrapper.usr.isactive);                
            }
                        
        } catch (Exception e) {
            throw new PlayerException('Error creating User for new player: ' + e.getMessage());
        }
        
        // Create the Player object that will be associated with the User
        createPlayerObject(userId);
        
        // Retrieve the details for the newly created player
        refreshPlayerDetails(userId);
    }
        
    /*
     * This does the work of updating an existing player. It first updates the User for the player. It
     * does this as a web service so that it is an atomic transaction. If successful, then we apply values
     * from the updated User to the Player object.
     */
    @TestVisible private void updatePlayer() {
        String userId;       
        try {
            System.debug('Updating User: ' + wrapper.usr);
                        
            SoapUtils.PoolManagerUtils soap = new SoapUtils.PoolManagerUtils();
            
            // Determine the endpoing dynamically
            soap.endpoint_x = webServiceUrl + '/class/PoolManagerUtils';            
            System.debug('Soap Endpoint = ' + soap.endpoint_x);
                 
            soap.SessionHeader = new SoapUtils.SessionHeader_element();           
            soap.SessionHeader.sessionId = UserInfo.getSessionId();           
            System.debug('Session ID: ' + UserInfo.getSessionId());
            
            // Update the User
            if (true != underTest) {
            
                System.debug('PlayerWrapper: ' + wrapper);
                
                userId = soap.updatePlayerUser(wrapper.usr.id, 
                    wrapper.usr.firstname, wrapper.usr.lastname, 
                    wrapper.usr.username, wrapper.usr.communitynickname, 
                    wrapper.usr.email, wrapper.usr.phone, 
                    wrapper.usr.street, wrapper.usr.city,
                    wrapper.usr.state, wrapper.usr.postalcode,
                    wrapper.usr.profileid, wrapper.usr.isactive);
                    
                System.debug('Successfully updated User for player. User ID: ' + userId);
            }                               
                        
        } catch (Exception e) {
            throw new PlayerException('Error updating User for player: ' + e.getMessage());
        }
        
        // Update the Player object
        String playerId;
        if (wrapper.player != null) {
                        
            updatePlayerObject(wrapper.player.id, userId);
            
        // If there is no Player object, try to create one now            
        } else {
            
            // Create the Player object that will be associated with the User
            createPlayerObject(userId);
        }
        
        // Refresh the player details
        refreshPlayerDetails(userId);
                
        System.debug('Updated Player object: ' + wrapper.player);   
    }
    
    /* Method to create the Player object. This copies the name from the
     * passed in User to the Player name field and relates the Player object
     * to the User object
     */
    @TestVisible private Id createPlayerObject(String userId) {
        try {
            User usr = [select id, name, phone, communitynickname from user where id = :userId limit 1];
            Player__c p = new Player__c();
            p.name = usr.name;
            p.user__c = usr.id;
            p.phone__c = usr.phone;
            p.nickname__c = usr.communitynickname;            
            insert p;
            System.debug('Successfully created Player object:' + p);
            return p.id;
        } catch (Exception e) {
            throw new PlayerException('Unable to create new Player object for player: ' + e.getMessage());
        }
    }

    /* Updates an existing Player object with data from the passed in User object */  
    @TestVisible private Id updatePlayerObject(String playerId, String userId) {
        try {
            User usr = [select id, name, phone, street, city, state, postalcode, communitynickname 
                from user where id = :userId limit 1];
            Player__c p = [select id, name, phone__c, nickname__c 
                from player__c where id=:playerId limit 1];
            p.name = usr.name;
            p.user__c = usr.id;
            p.phone__c = usr.phone;
            p.nickname__c = usr.communitynickname;            
            update p;
            System.debug('Successfully updated Player object:' + p);
            return p.id;
            
        } catch (Exception e) {
            throw new PlayerException('Unable to update Player object for player: ' + e.getMessage());
        }
    }
    
    /* Payment handling stuff */
    public class PaymentWrapper {       
        public Integer index { get; set; }
        public PlayerPayment__c payment { get; set; }
        public String mode { get; set; }
        public PaymentWrapper(Integer index, PlayerPayment__c payment, String mode) {
            this.index = index;
            this.payment = payment;
            this.mode = mode;
        }
    }
    
    public PageReference addPayment() {
        Integer currentSize = pmtWrappers.size();
        PlayerPayment__c newPayment = new PlayerPayment__c(Player__c = wrapper.player.Id);
        PaymentWrapper newWrapper = new PaymentWrapper(currentSize, newPayment, MODE_EDIT);
        pmtWrappers.add(newWrapper);
        editingPayment = true;
        return null;        
    }
    
    public PageReference editPayment() {
        Integer paymentIndex = Integer.valueOf(
            ApexPages.currentPage().getParameters().get('paymentIndex'));
        PaymentWrapper pmtWrapper = pmtWrappers.get(paymentIndex);
        pmtWrapper.mode = MODE_EDIT;
        editingPayment = true;
        return null;
    }
    
    public PageReference deletePayment() {
        
        Integer paymentIndex = Integer.valueOf(
            ApexPages.currentPage().getParameters().get('paymentIndex'));
        PaymentWrapper pmtWrapper = pmtWrappers.remove(paymentIndex);
        
        try {
            delete pmtWrapper.payment;      
        } catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                    'Error deleting payment: ' + ex.getMessage()));
            return null;            
        }       
        
        refreshPlayerDetails(wrapper.usr.id);
        return null;
    }
    
    public PageReference savePayment() {
        
        Integer paymentIndex = Integer.valueOf(
            ApexPages.currentPage().getParameters().get('paymentIndex'));
        PaymentWrapper pmtWrapper = pmtWrappers.get(paymentIndex);
        
        // Check if payment amount is greater than the balance due. If so, it's an error
        if (pmtWrapper.payment.amount__c > wrapper.player.BalanceDueFormula__c) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                    'The payment amount is greater than the balance due. Payment could not be saved.'));
            return null;  
        }
        
        try {
            upsert pmtWrapper.payment;
        } catch (Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                    'Error saving payment: ' + ex.getMessage()));
            return null;            
        }
                
        pmtWrapper.mode = MODE_VIEW;
        refreshPlayerDetails(wrapper.usr.id);
        editingPayment = false;
        return null;
    }
    
    public PageReference cancelPayment() {
        Integer paymentIndex = Integer.valueOf(
            ApexPages.currentPage().getParameters().get('paymentIndex'));
        PaymentWrapper pmtWrapper = pmtWrappers.get(paymentIndex);
        
        // If this is an existing payment
        if (pmtWrapper.payment.id != null) {
            
            // Retrieve the original payment
            PlayerPayment__c originalPayment = [select id, createddate, createdbyid, amount__c, paymentdate__c
                from playerpayment__c where id=:pmtWrapper.payment.id limit 1];
            pmtWrapper.payment = originalPayment;
            pmtWrapper.mode = MODE_VIEW;
            
        // We're cancelling the addition of a new payment so just remove it from the list
        } else {
            pmtWrappers.remove(paymentIndex);
        }
        
        refreshPlayerDetails(wrapper.usr.id);
        editingPayment = false;
        return null;
    }
}