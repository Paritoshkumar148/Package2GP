/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 01-15-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@SuppressWarnings('PMD')
public with sharing class GenericPermissionSetAssignerHandler {

/**
     * @description Checking User Object is accessible for user or not.
     * @return Returning value is accessible user object.
    **/    
@AuraEnabled(cacheable=true)
    public static boolean isAccForUserObje(){
        boolean isUserAndPermissionSetObjAccess;
        if(Schema.sObjectType.User.isAccessible() && Schema.sObjectType.PermissionSetAssignment.isAccessible()){
            isUserAndPermissionSetObjAccess = true;
        }
        return isUserAndPermissionSetObjAccess;
    }
/**
     * @description Retriving All Active and Inactive Users.
     * @return Returning List of Source User.
    **/    
@AuraEnabled(cacheable=true)
    public static List<User> getSourceUsers() {
        
      return [SELECT Id, Name, IsActive, Profile.UserLicense.Name 
              FROM User 
              WHERE Profile.UserLicense.Name NOT IN('Analytics Cloud Integration User', 'Analytics Cloud Integration Use', 'Chatter Free')WITH SECURITY_ENFORCED];
    }
/**
 * @description Retrieves all active target users with the same license as the selected source user.
 * @param userId The Id of the source user whose license is being used for filtering target users.
 * @param targetUserId The Id of the user to exclude from the target user list.
 * @return A list of active users (target users) with the same license as the source user.
 **/  
@AuraEnabled(cacheable=true)
    public static List<User> getTargetUsers(Id userId, Id targetUserId){
       List<User> sourceUser=[SELECT Id, Name, IsActive, Profile.UserLicense.Name 
                         FROM User
                         WHERE Id = :userId  WITH SECURITY_ENFORCED
                         LIMIT 1];
      
      List<User> targetUsers=[SELECT Id, Name, IsActive, Profile.UserLicense.Name
                              FROM User 
                              WHERE Id != :userId AND Profile.UserLicense.Name =:sourceUser[0].Profile.UserLicense.Name AND IsActive=true  WITH SECURITY_ENFORCED];
      getSourcePermissionSet(userId);
      return targetUsers;         
}
/**
     * @description Retriving sourceUser Assigned permission From org.
     * @param sourceUser The Id of the selected source user whose assigned permission sets need to be retrieved.
     * @return Returning List of assigned Permission Sets of Selected source user is.
    **/

@AuraEnabled(cacheable= true)
        public static List<PermissionSetAssignment> getSourcePermissionSet(Id sourceUser) {
         String standardPSAssignToUser = 'X00%';
          return [SELECT  PermissionSet.Name, PermissionSetId
                  FROM PermissionSetAssignment
                  WHERE AssigneeId = : sourceUser 
                  AND (NOT PermissionSet.Name LIKE :standardPSAssignToUser) WITH SECURITY_ENFORCED];
        }
/**
 * @description Retriving PermissionSet Assigned Of Target User From Org.
 * @param targetUser The Id of the target user whose permission sets are to be retrieved.
 * @return A list of assigned permission sets of selected target user.
 **/    
@AuraEnabled(cacheable=true)
      public static List<PermissionSetAssignment> getTargetPermissionSet(Id targetUser){
      String standardPSAssignToUser = 'X00%';
          return [SELECT  PermissionSet.Name, PermissionSetId
          FROM PermissionSetAssignment
          WHERE AssigneeId = : targetUser 
          
          AND (NOT PermissionSet.Name LIKE :standardPSAssignToUser) WITH SECURITY_ENFORCED];
      }
/**
 * @description Assigns selected custom permission sets to a target user and removes unselected permissions.
 * @param customSource A JSON string representing the custom permission sets assigned to the source user.
 * @param customTarget A JSON string representing the custom permission sets assigned to the target user.
 * @param sourceUserId The Id of the source user whose permissions are being referenced.
 * @param targetUserId The Id of the target user to whom the custom permissions are assigned.
 * @return void
 **/
@AuraEnabled()
    public static void assignCustomPermissionSetsToTargetUser(
                                                    string customSource, 
                                                    string customTarget,
                                                    Id sourceUserId,
                                                    Id targetUserId
                                                    ){
                 Schema.SObjectType objType = Schema.getGlobalDescribe().get('PermissionSetAssignment');
                 Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
                Map<String, Boolean> customSourcePermission = (Map<String, Boolean>) JSON.deserialize(customSource, Map<String, Boolean>.class);
                Map<String, Boolean> customTargetPermission = (Map<String, Boolean>) JSON.deserialize(customTarget, Map<String, Boolean>.class);
             
                List<PermissionSet> assignedPSSource = [SELECT Id
                                                        FROM PermissionSet 
                                                        WHERE Id IN :customSourcePermission.keySet() WITH SECURITY_ENFORCED];
                List<PermissionSet> assignedPSTarget = [SELECT Id
                                                        FROM PermissionSet
                                                        WHERE Id IN :customTargetPermission.keySet() WITH SECURITY_ENFORCED];
      
                List<permissionSetAssignment> psaListToBeInserted = new List<PermissionSetAssignment>();
                Map<Id,Boolean> permissionSetAssignmentIds = new Map<Id,Boolean>();
                for(PermissionSet ps: assignedPSSource){
                  if(!permissionSetAssignmentIds.containsKey(ps.id) ){
                      permissionSetAssignmentIds.put(ps.Id, customSourcePermission.get(ps.Id));
                    
                  }
                }
                for(Permissionset ps: assignedPSTarget){
                  if(!permissionSetAssignmentIds.containsKey(ps.Id)){
                      permissionSetAssignmentIds.put(ps.Id, customTargetPermission.get(ps.Id));                
                  }
                }

                String standardPSAssignToUser = 'X00%';                                       
                List<PermissionSetAssignment> permissionSetAssignments = [SELECT Id
                                                                          FROM PermissionSetAssignment
                                                                          WHERE  AssigneeId = :targetUserId
                                                                          AND (NOT PermissionSet.Name LIKE :standardPSAssignToUser) WITH SECURITY_ENFORCED
                                                                          ];

                Map<Id,PermissionSetAssignment> deletedpermissionSetAssignmentmap = new Map<Id,PermissionSetAssignment>();                                                        
                for(PermissionSetAssignment psa: PermissionSetAssignments){
                  deletedpermissionSetAssignmentmap.put(psa.id,psa);
                }
                  if(permissionSetAssignments.size()>0 && objDescribe.isDeletable()){
                    try {
                        delete permissionSetAssignments;
                      }
                      catch (Exception e) { throw new AuraHandledException(e.getMessage());
                    }
                  }
                  
                for (Id psId : permissionSetAssignmentIds.keySet()) {
                    if(!deletedpermissionSetAssignmentmap.containsKey(psId) ){
                        psaListToBeInserted.add(new PermissionSetAssignment(
                                                AssigneeId=targetUserId,
                                                PermissionSetId=psId )
                );
                      }
              }
                
                if(psaListToBeInserted.size()>0 && objDescribe.isCreateable() && objDescribe.isUpdateable()){
                    try {
                        upsert psaListToBeInserted;

                    } catch (Exception e) {
                        throw new AuraHandledException(e.getMessage());
                    }
                  }else {    
                        throw new AuraHandledException('Failure : entity type cannot be inserted: Permission Set Assignment');
                        }
      }
/**
 * @description Upgrades the permission sets assigned to a target user by adding selected or source user's non-standard permission sets.
 * @param sourceUserId The Id of the source user whose permission sets may be referenced for the upgrade.
 * @param targetUserId The Id of the target user whose permission sets are to be upgraded.
 * @param upgradeTarget A JSON string representing the permission sets to be upgraded for the target user.
 **/
@AuraEnabled
  public static void upgradePermissionSetoftargetUser(Id sourceUserId,
                                                      Id targetUserId,
                                                      String upgradeTarget){
            Schema.SObjectType objType = Schema.getGlobalDescribe().get('PermissionSetAssignment');
            Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
            Map<String, Boolean> upgradeTargetPermission = (Map<String, Boolean>) JSON.deserialize(upgradeTarget, Map<String, Boolean>.class);
            List<PermissionSetAssignment> psaNeedToBeUpgratedForTargetUser = new List<PermissionSetAssignment>();
            List<Id> targetUserpermissionSetIds = new List<Id>();
            String standardPSAssignToUser = 'X00%';
            //Retriving assigned permissions of target user.
            List<PermissionSetAssignment> assignedTargetPermissions = [SELECT PermissionSetId 
                                                                      FROM PermissionSetAssignment
                                                                      WHERE AssigneeId = :targetUserId 
                                                                      AND (NOT PermissionSet.Name LIKE :standardPSAssignToUser) WITH SECURITY_ENFORCED
                                                                     ]; 
            
            for(PermissionSetAssignment psa: assignedTargetPermissions){
              targetUserpermissionSetIds.add(psa.PermissionSetId);
            }
            if(upgradeTargetPermission.size()>0){
              for(Id psId: upgradeTargetPermission.keySet()){
                if(!targetUserpermissionSetIds.contains(psId) && upgradeTargetPermission.get(psId)){
                  psaNeedToBeUpgratedForTargetUser.add(new PermissionSetAssignment(
                                                AssigneeId=targetUserId,
                                                PermissionSetId=psId ));}}
            }else{
                String standardPSAssignToUser1 = 'X00%';
                List<PermissionSetAssignment> psaIds = [SELECT  PermissionSet.Name, PermissionSetId
                                              FROM PermissionSetAssignment
                                              WHERE AssigneeId = :sourceUserId 
                                              AND (NOT PermissionSet.Name LIKE :standardPSAssignToUser1) WITH SECURITY_ENFORCED
                                              ];
            for(PermissionSetAssignment psId: psaIds){
              if(!targetUserpermissionSetIds.contains(psId.id)){
                psaNeedToBeUpgratedForTargetUser.add(new PermissionSetAssignment(
                                              AssigneeId=targetUserId,
                                              PermissionSetId=psId.PermissionSetId ));}}                        
            }
              
           if(psaNeedToBeUpgratedForTargetUser.size()>0 && objDescribe.isUpdateable() && objDescribe.isCreateable()){
            try {
              upsert psaNeedToBeUpgratedForTargetUser;}
               catch (Exception e) {
                throw new AuraHandledException(e.getMessage());
            }
          }else{
              throw new AuraHandledException('Failure : entity type cannot be inserted: Permission Set Assignment');
            }

}   
/**
 * @description Clones selected or source user permission sets to a target user, Removes any existing non-standard permission sets before cloning.
 * @param cloneTarget A JSON string representing the permission sets to be cloned to the target user.
 * @param sourceUserId The Id of the source user whose permission sets are referenced for cloning.
 * @param targetUserId The Id of the target user to whom the permission sets are being cloned.
 **/                                                  
@AuraEnabled
  public static void clonePermissionSetOfTargetUser(
                                                    String cloneTarget,
                                                    Id sourceUserId,
                                                    Id targetUserId
                                                    ){
          Schema.SObjectType objType = Schema.getGlobalDescribe().get('PermissionSetAssignment');
          Schema.DescribeSObjectResult objDescribe = objType.getDescribe();

          Map<String, Boolean> cloneTargetPermission = (Map<String, Boolean>) JSON.deserialize(cloneTarget, Map<String, Boolean>.class);
          String standardPSAssignToUser = 'X00%';
          List<PermissionSetAssignment> psaNeedToBeClonedForTargetUser = new List<PermissionSetAssignment>();
          List<PermissionSetAssignment> targetUserAssignedPermissions = [SELECT PermissionSetId 
                                                                          FROM PermissionSetAssignment
                                                                          WHERE AssigneeId = :targetUserId 
                                                                          AND (NOT PermissionSet.Name LIKE :standardPSAssignToUser) WITH SECURITY_ENFORCED
                                                                          ];
          
          if(targetUserAssignedPermissions.size()>0 && objDescribe.isDeletable()){
               delete targetUserAssignedPermissions;
          }

          if(cloneTargetPermission.size()>0){
            for(Id psId: cloneTargetPermission.keySet()){
              if(cloneTargetPermission.get(psId)){
                psaNeedToBeClonedForTargetUser.add(new PermissionSetAssignment(
                  AssigneeId=targetUserId,
                  PermissionSetId=psId ));
              }
            }
          }else{                 
                  List<PermissionSetAssignment> PSAIds = [SELECT  PermissionSet.Name, PermissionSetId
                                                          FROM PermissionSetAssignment
                                                          WHERE AssigneeId = :sourceUserId
                                                          AND (NOT PermissionSet.Name LIKE :standardPSAssignToUser) WITH SECURITY_ENFORCED];
              
                      for(PermissionSetAssignment psId: PSAIds){
                                        psaNeedToBeClonedForTargetUser.add(new PermissionSetAssignment(
                                        AssigneeId=targetUserId,
                                        PermissionSetId=psId.PermissionSetId ));
                                }
              
          }
          
          if (psaNeedToBeClonedForTargetUser.size()>0 && objDescribe.isCreateable() && objDescribe.isUpdateable()) {
            try {
              upsert psaNeedToBeClonedForTargetUser;}
               catch (Exception e) {
                throw new AuraHandledException(e.getMessage());
            }
            
          }else{
              throw new AuraHandledException('Failure : entity type cannot be inserted: Permission Set Assignment');
               } 
}  
  
}