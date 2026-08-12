import { LightningElement, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import getSettings from "@salesforce/apex/SettingsService.getSettings";
import getProfileOptions from "@salesforce/apex/PlayerService.getProfileOptions";
import getPlayerList from "@salesforce/apex/PlayerService.getPlayerList";
import getPlayer from "@salesforce/apex/PlayerService.getPlayer";
import activateUser from "@salesforce/apex/PlayerService.activateUser";
import deactivateUser from "@salesforce/apex/PlayerService.deactivateUser";
import createUser from "@salesforce/apex/PlayerService.createUser";
import updateUser from "@salesforce/apex/PlayerService.updateUser";
import savePlayerRecord from "@salesforce/apex/PlayerService.savePlayerRecord";
import savePayment from "@salesforce/apex/PlayerService.savePayment";
import deletePayment from "@salesforce/apex/PlayerService.deletePayment";

const MODE_VIEW = "view";
const MODE_EDIT = "edit";
const MODE_NEW = "new";

export default class PlayerManagement extends LightningElement {
  activeOnly = true;
  players = [];
  profileOptions = [];
  usernameSuffix = "";

  isLoading = false;
  loadError;

  selectedUserId;
  panelMode; // undefined | 'view' | 'edit' | 'new'
  panelDetail; // { usr, player, payments }
  isPanelLoading = false;
  isSaving = false;
  panelError;

  @wire(getSettings)
  wiredSettings({ data }) {
    if (data) {
      this.usernameSuffix = data.UsernameSuffix__c || "";
    }
  }

  @wire(getProfileOptions)
  wiredProfileOptions({ data, error }) {
    if (data) {
      this.profileOptions = data;
    } else if (error) {
      this.profileOptions = [];
    }
  }

  connectedCallback() {
    this.loadPlayers();
  }

  // Lightning App Page tabs can stay mounted in the background when the user
  // navigates away, so refetch on return -- but only while the panel is
  // closed, so we don't clobber an admin's in-progress edit (same guard
  // games.js uses).
  @wire(CurrentPageReference)
  handleCurrentPageReference(pageReference) {
    if (pageReference && !this.isPanelOpen) {
      this.loadPlayers();
    }
  }

  async loadPlayers() {
    this.isLoading = true;
    this.loadError = undefined;
    try {
      this.players = await getPlayerList({ activeOnly: this.activeOnly });
    } catch (error) {
      this.loadError = this.reduceError(error);
      this.players = [];
    } finally {
      this.isLoading = false;
    }
  }

  handleActiveOnlyToggle() {
    this.activeOnly = !this.activeOnly;
    this.loadPlayers();
  }

  get activeOnlyLabel() {
    return this.activeOnly ? "Active Players" : "All Players (Includes Inactive)";
  }

  get toggleButtonLabel() {
    return this.activeOnly ? "Show All" : "Show Active Only";
  }

  get playerRows() {
    return (this.players || []).map((detail) => {
      const usr = detail.usr || {};
      const player = detail.player;
      return {
        key: usr.Id,
        userId: usr.Id,
        name: usr.Name,
        nickname: usr.CommunityNickname,
        username: usr.Username,
        phone: usr.Phone,
        email: usr.Email,
        balanceDue: player ? player.BalanceDueFormula__c : null,
        profileName: usr.Profile ? usr.Profile.Name : "",
        isActive: usr.IsActive,
        activeLabel: usr.IsActive ? "Active" : "Inactive",
        activeIconName: usr.IsActive ? "utility:check" : "utility:close"
      };
    });
  }

  get hasPlayers() {
    return this.playerRows.length > 0;
  }

  get isPanelOpen() {
    return !!this.panelMode;
  }

  get isPanelNew() {
    return this.panelMode === MODE_NEW;
  }

  handleTableActivateClick(event) {
    this.confirmAndActivate(event.currentTarget.dataset.userid);
  }

  handleTableDeactivateClick(event) {
    this.confirmAndDeactivate(event.currentTarget.dataset.userid);
  }

  handleTableViewClick(event) {
    this.openPanel(event.currentTarget.dataset.userid, MODE_VIEW);
  }

  handleCardActivate(event) {
    this.confirmAndActivate(event.detail.userId);
  }

  handleCardDeactivate(event) {
    this.confirmAndDeactivate(event.detail.userId);
  }

  handleCardSelect(event) {
    this.openPanel(event.detail.userId, MODE_VIEW);
  }

  async confirmAndActivate(userId) {
    try {
      await activateUser({ userId });
      await this.loadPlayers();
      if (this.selectedUserId === userId) {
        await this.refreshPanelDetail();
      }
    } catch (error) {
      this.loadError = this.reduceError(error);
    }
  }

  async confirmAndDeactivate(userId) {
    try {
      await deactivateUser({ userId });
      await this.loadPlayers();
      if (this.selectedUserId === userId) {
        await this.refreshPanelDetail();
      }
    } catch (error) {
      this.loadError = this.reduceError(error);
    }
  }

  async openPanel(userId, mode) {
    this.selectedUserId = userId;
    this.panelMode = mode;
    this.panelError = undefined;
    this.isPanelLoading = true;
    try {
      this.panelDetail = await getPlayer({ userId });
    } catch (error) {
      this.panelError = this.reduceError(error);
      this.panelDetail = undefined;
    } finally {
      this.isPanelLoading = false;
    }
  }

  handleNewPlayer() {
    this.selectedUserId = undefined;
    this.panelMode = MODE_NEW;
    this.panelError = undefined;
    this.panelDetail = {
      usr: {
        Username: `<first.last>@${this.usernameSuffix}`,
        IsActive: true
      },
      player: null,
      payments: []
    };
  }

  async refreshPanelDetail() {
    if (!this.selectedUserId) {
      return;
    }
    try {
      this.panelDetail = await getPlayer({ userId: this.selectedUserId });
    } catch (error) {
      this.panelError = this.reduceError(error);
    }
  }

  handlePanelEdit() {
    this.panelMode = MODE_EDIT;
  }

  async handlePanelCancel() {
    if (this.panelMode === MODE_NEW) {
      this.closePanel();
      return;
    }
    this.panelMode = MODE_VIEW;
    await this.refreshPanelDetail();
  }

  closePanel() {
    this.selectedUserId = undefined;
    this.panelMode = undefined;
    this.panelDetail = undefined;
    this.panelError = undefined;
  }

  // The dirty check (and its confirm prompt) already happened in
  // c-player-detail-panel before it dispatched close/cancel -- don't
  // duplicate it here.
  handlePanelClose() {
    this.closePanel();
  }

  async handlePanelSave(event) {
    const usr = event.detail.usr;
    this.isSaving = true;
    this.panelError = undefined;
    try {
      let userId;
      if (this.panelMode === MODE_NEW) {
        userId = await createUser({
          firstname: usr.FirstName,
          lastname: usr.LastName,
          username: usr.Username,
          nickname: usr.CommunityNickname,
          email: usr.Email,
          phone: usr.Phone,
          street: usr.Street,
          city: usr.City,
          state: usr.State,
          postalcode: usr.PostalCode,
          profileId: usr.ProfileId,
          isActive: true
        });
      } else {
        userId = await updateUser({
          userId: this.selectedUserId,
          firstname: usr.FirstName,
          lastname: usr.LastName,
          username: usr.Username,
          nickname: usr.CommunityNickname,
          email: usr.Email,
          phone: usr.Phone,
          street: usr.Street,
          city: usr.City,
          state: usr.State,
          postalcode: usr.PostalCode,
          profileId: usr.ProfileId,
          isActive: usr.IsActive
        });
      }
      await savePlayerRecord({ userId });
      this.selectedUserId = userId;
      this.panelMode = MODE_VIEW;
      await this.refreshPanelDetail();
      await this.loadPlayers();
    } catch (error) {
      this.panelError = this.reduceError(error);
    } finally {
      this.isSaving = false;
    }
  }

  async handlePanelSavePayment(event) {
    const { payment, balanceDue } = event.detail;
    this.panelError = undefined;
    try {
      await savePayment({ payment, balanceDue });
      await this.refreshPanelDetail();
      await this.loadPlayers();
    } catch (error) {
      this.panelError = this.reduceError(error);
    }
  }

  async handlePanelDeletePayment(event) {
    const { paymentId } = event.detail;
    this.panelError = undefined;
    try {
      await deletePayment({ paymentId });
      await this.refreshPanelDetail();
      await this.loadPlayers();
    } catch (error) {
      this.panelError = this.reduceError(error);
    }
  }

  reduceError(error) {
    if (error && error.body && error.body.message) {
      return error.body.message;
    }
    if (error && error.message) {
      return error.message;
    }
    return "An unknown error occurred.";
  }
}
