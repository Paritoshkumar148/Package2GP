import { LightningElement,track ,wire} from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import assignCustomPermissionSetsToTargetUser from '@salesforce/apex/GenericPermissionSetAssignerHandler.assignCustomPermissionSetsToTargetUser';
import clonePermissionSetOfTargetUser from '@salesforce/apex/GenericPermissionSetAssignerHandler.clonePermissionSetOfTargetUser';

import getSourcePermissionSet from '@salesforce/apex/GenericPermissionSetAssignerHandler.getSourcePermissionSet';
import getSourceUsers from '@salesforce/apex/GenericPermissionSetAssignerHandler.getSourceUsers';
import getTargetPermissionSet from '@salesforce/apex/GenericPermissionSetAssignerHandler.getTargetPermissionSet';
import getTargetUsers from '@salesforce/apex/GenericPermissionSetAssignerHandler.getTargetUsers';
import isAccForUserObje from '@salesforce/apex/GenericPermissionSetAssignerHandler.isAccForUserObje';
import upgradePermissionSetoftargetUser from '@salesforce/apex/GenericPermissionSetAssignerHandler.upgradePermissionSetoftargetUser';
export default class GenericPermissionSetAssignerComponent extends LightningElement {
    @track optionsForSource = [];
    @track optionsForTarget = [];
    @track sourceUserAssignPS = [];
    @track targetUserAssignPS = [];
    targetCustomPermissions = new Map();
    sourceCustomPermissions = new Map();
    targetUpgradePermissions = new Map();
    targetClonePermissions = new Map();
    isUserObjAccessible = false;
    isLoaded = false;
    errorMessage;
    @track upgradePermission = false;
    @track clonePermission = false;
    @track customPermission = false;
    @track sourceUserId;
    @track targetUserId;

    showToast(title, message, variant) {
        if(!import.meta.env.SSR){
            this.dispatchEvent(
                new ShowToastEvent({
                    message,
                    title,
                    variant,
                })
            );
        }
        
    }


    checkUserObjectAccessibility() {
        isAccForUserObje()
            .then((data) => {   
                this.isUserObjAccessible = data;
                if(this.isUserObjAccessible){
                    this.loadSourceUsers();
                }else{
                    this.showToast(
                        'Insufficient Access',
                        `Contact Your System Administrator: You have No access of user & PermissionSetAssignment Object.`,
                        'Error'
                    );   
                }
            })
            .catch((error) => {     
                this.errorMessage = error.body.message;
                this.showToast(
                    'Insufficient Access',
                    `Contact Your System Administrator: ${this.errorMessage}`,
                    'Error'
                );
            })
            .finally(() => {
                this.isLoaded = true;
            });
    }

   connectedCallback() {
    this.checkUserObjectAccessibility();
       
    }

    loadSourceUsers() {
        getSourceUsers()
            .then((data) => {
                const allUsers = [];
                data.forEach((user) => {
                    allUsers.push({ label: user.Name, value: user.Id });
                });
                this.optionsForSource = allUsers;
            })
            .catch((error) => {
                const errorMessage = error.body.message;
                this.showToast('No user exists in this org.', `Error Fetching Source User: ${errorMessage}`, 'Error');
            });
    }

    handleSourceChange(event) {
        this.sourceUserId = event.detail.value;
    }

    handleTargetChange(event) {
        this.targetUserId = event.detail.value;
    }

    @wire(getTargetUsers, { userId: '$sourceUserId' })
    Targetusers({ error, data }) {
        if (data) {
            const allUsers = [];
            data.forEach(user => {
                allUsers.push({ label: user.Name, value: user.Id });
            });
            this.optionsForTarget = allUsers;
        } else if(error) {
            const errorMessage = error.body.message;
            this.showToast('Error Retriving Target User.',`Error fetching target User: ${errorMessage}`,'Error');
        }else{
            this.showToast('Error Retriving Target User.','Error fetching target User.','Error'); 
        }
    }


    @wire(getSourcePermissionSet, { sourceUser: '$sourceUserId' })
    SourceUserAssignedPS({ error, data }) {
        if (data) {
            const allSourcePermissionSet = [];
            data.forEach(PermissionSetAssignment => {
                allSourcePermissionSet.push({
                    label: PermissionSetAssignment.PermissionSet.Name,
                    value: PermissionSetAssignment.PermissionSetId
                });

            });
            this.sourceUserAssignPS = allSourcePermissionSet;
        } else if(error) {
            const errorMessage = error.body.message;
            this.showToast('Error Retriving Source User Permission Set.',`Error fetching source User Permission Set: ${errorMessage}`,'Error' );
        }else{
            this.showToast('Error Retriving Source User Permission Set.','Error fetching source User Permission Set.','Error' ); 
        }
    }

    @wire(getTargetPermissionSet, { targetUser: '$targetUserId' })
    TargetUserAssignedPS({ error, data }) {
        if (data) {
            const allTargetPermissionSet = [];
            data.forEach(PermissionSetAssignment => {
                allTargetPermissionSet.push({
                    label: PermissionSetAssignment.PermissionSet.Name,
                    value: PermissionSetAssignment.PermissionSetId
                });
            });
            this.targetUserAssignPS = allTargetPermissionSet;
        } else if(error){
            const errorMessage = error.body.message;
            this.showToast('Error Retriving Target User Permission Set.', `Error fetching target User Permission Set: ${errorMessage}`,'Error' );
        }else{
            this.showToast('Error Retriving Target User Permission Set.', 'Error fetching target User Permission Set.','Error' );
        }
    }

    handlePermissionSetChangeSource(event) {
        this.sourceCustomPermissions[event.target.dataset.id] = event.target.checked;
    }

    handlePermissionSetChangeTarget(event) {
        this.targetCustomPermissions[event.target.dataset.id] = event.target.checked;
    }

    handlePermissionSetChangeUpgradeSource(event) {
        this.targetUpgradePermissions[event.target.dataset.id] = event.target.checked;
    }
    handlePermissionSetChangeCloneSource(event) {
        this.targetClonePermissions[event.target.dataset.id] = event.target.checked;
    }

    handleClonePermission(event) {
        this.clonePermission = event.target.checked;
        this.upgradePermission = false;
        this.customPermission = false;

    }

    handleUpgradePermission(event) {
        this.upgradePermission = event.target.checked;
        this.clonePermission = false;
        this.customPermission = false;

    }

    handleCustomPermission(event) {
        this.customPermission = event.target.checked;
        this.clonePermission = false;
        this.upgradePermission = false;

    }

 
        handleSave() {
            if (this.isValidInputs()) {
                if (this.customPermission) {
                    this.assignCustomPermissions();
                } else if (this.upgradePermission) {
                    this.upgradePermissions();
                } else if (this.clonePermission) {
                    this.clonePermissions();
                }
            } else {
                this.showValidationErrors();
            }
        }
        
        // Check if the inputs are valid
        isValidInputs() {
            return this.sourceUserId && this.targetUserId &&
                (this.upgradePermission || this.clonePermission || this.customPermission) &&
                (Object.keys(this.sourceCustomPermissions).length || Object.keys(this.targetCustomPermissions).length || 
                Object.keys(this.targetClonePermissions).length || Object.keys(this.targetUpgradePermissions).length);
        }
        
        // Show validation error messages
        showValidationErrors() {
            if (this.sourceUserId && !this.targetUserId) {
                this.showToast('TargetUser is Null', 'Please select target user', 'error');
            } else if (!this.sourceUserId && this.targetUserId) {
                this.showToast('SourceUser Is Null', 'Please select source user', 'error');
            } else if (!this.sourceUserId && !this.targetUserId) {
                this.showToast('SourceUser TargetUser Haven\'t selected', 'Please select source and target user', 'error');
            } else if (!this.upgradePermission && !this.clonePermission && !this.customPermission) {
                this.showToast('Select any Type of Permission Custom/Upgrade/Clone', 'Please select any one Permission type', 'error');
            } else {
                this.showToast('Select Permission Sets which need to be assigned to Target User', 'Please select at least one/more Permission Sets', 'error');
            }
        }
        
        // Assign custom permissions to the target user
        assignCustomPermissions() {
            assignCustomPermissionSetsToTargetUser({
                customSource: JSON.stringify(this.sourceCustomPermissions),
                customTarget: JSON.stringify(this.targetCustomPermissions),
                sourceUserId: this.sourceUserId,
                targetUserId: this.targetUserId                    
            })
            .then(result => {
                this.showToast('Success', 'Permissions are being assigned successfully', 'success');
            })
            .catch(error => {
                this.handlePermissionAssignmentError(error);
            });
        }
        
        // Upgrade permissions for the target user
        upgradePermissions() {
            upgradePermissionSetoftargetUser({
                sourceUserId: this.sourceUserId,
                targetUserId: this.targetUserId,
                upgradeTarget: JSON.stringify(this.targetUpgradePermissions),
            })
            .then(result => {
                this.showToast('Success', 'Permissions are being assigned successfully', 'success');
            })
            .catch(error => {
                this.handlePermissionAssignmentError(error);
            });
        }
        
        // Clone permissions for the target user
        clonePermissions() {
            clonePermissionSetOfTargetUser({
                cloneTarget: JSON.stringify(this.targetClonePermissions),
                sourceUserId: this.sourceUserId,
                targetUserId: this.targetUserId
            })
            .then(result => {
                this.showToast('Success', 'Permissions are being assigned successfully', 'success');
            })
            .catch(error => {
                this.handlePermissionAssignmentError(error);
            });
        }
        
        // Handle error for permission assignment
        handlePermissionAssignmentError(error) {
            const errorMessage = error.body.message;
            this.showToast('Failed to Assign Permission Set ', `${errorMessage}`, 'error');
        }
        
}