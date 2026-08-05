import { LightningElement, wire } from "lwc";
import { CurrentPageReference, NavigationMixin } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";
import getSelectionsForPlayerWeek from "@salesforce/apex/SelectionService.getSelectionsForPlayerWeek";
import getActivePlayers from "@salesforce/apex/SelectionService.getActivePlayers";
import getCurrentPlayerIdForUser from "@salesforce/apex/SelectionService.getCurrentPlayerIdForUser";
import isCurrentUserAdmin from "@salesforce/apex/SettingsService.isCurrentUserAdmin";
import getWeekNumbers from "@salesforce/apex/SettingsService.getWeekNumbers";
import getSettings from "@salesforce/apex/SettingsService.getSettings";

const NONE_PLAYER_OPTION = { label: "-- None --", value: "" };
const MODE_VIEW = "view";
const MODE_EDIT = "edit";
const MODE_PRIVILEGED_EDIT = "privileged-edit";

export default class Selections extends NavigationMixin(LightningElement) {
  isAdmin = false;
  currentPlayerId;
  playerId = "";
  weekNumber;
  mode = MODE_VIEW;

  playerOptions = [NONE_PLAYER_OPTION];
  weekOptions = [];
  showPrivilegedEditConfirm = false;

  selectionsResult;

  @wire(isCurrentUserAdmin)
  wiredIsAdmin({ data, error }) {
    if (data !== undefined) {
      this.isAdmin = data;
      this.applyDefaultPlayer();
    } else if (error) {
      this.isAdmin = false;
    }
  }

  @wire(getCurrentPlayerIdForUser)
  wiredCurrentPlayerId({ data }) {
    if (data !== undefined) {
      this.currentPlayerId = data;
      this.applyDefaultPlayer();
    }
  }

  @wire(getSettings)
  wiredSettings({ data }) {
    if (data && !this.weekNumber && data.CurrentWeek__c != null) {
      this.weekNumber = String(data.CurrentWeek__c);
    }
  }

  @wire(getWeekNumbers)
  wiredWeekNumbers({ data, error }) {
    if (data) {
      this.weekOptions = data.map((week) => ({
        label: `Week ${week}`,
        value: week
      }));
    } else if (error) {
      this.weekOptions = [];
    }
  }

  @wire(getActivePlayers)
  wiredPlayers({ data, error }) {
    if (data) {
      this.playerOptions = [NONE_PLAYER_OPTION, ...data];
    } else if (error) {
      this.playerOptions = [NONE_PLAYER_OPTION];
    }
  }

  @wire(getSelectionsForPlayerWeek, {
    playerId: "$playerId",
    weekNumber: "$weekNumber"
  })
  wiredSelections(result) {
    this.selectionsResult = result;
  }

  // Lightning App Page tabs can stay mounted in the background when the user
  // navigates away, so connectedCallback/@wire won't naturally re-fire on
  // return. CurrentPageReference does fire on tab (re)activation, so use it
  // to force a refetch and avoid showing stale data from a previous visit.
  @wire(CurrentPageReference)
  handleCurrentPageReference(pageReference) {
    if (pageReference && this.selectionsResult) {
      refreshApex(this.selectionsResult);
    }
  }

  applyDefaultPlayer() {
    if (!this.isAdmin && !this.playerId && this.currentPlayerId) {
      this.playerId = this.currentPlayerId;
    }
  }

  get isLoading() {
    return !this.selectionsResult;
  }

  get loadError() {
    return this.selectionsResult && this.selectionsResult.error
      ? this.reduceError(this.selectionsResult.error)
      : undefined;
  }

  get selectionsData() {
    return this.selectionsResult && this.selectionsResult.data
      ? this.selectionsResult.data
      : undefined;
  }

  get gameSelections() {
    return this.selectionsData ? this.selectionsData.gameSelections : [];
  }

  get totalPoints() {
    return this.selectionsData ? this.selectionsData.totalPoints : 0;
  }

  get numGames() {
    return this.selectionsData ? this.selectionsData.numGames : 0;
  }

  get numSelections() {
    return this.selectionsData ? this.selectionsData.numSelections : 0;
  }

  get allLocked() {
    const list = this.gameSelections;
    return list.length > 0 && list.every((gs) => gs.isLocked);
  }

  get showPlayerPicker() {
    return this.isAdmin;
  }

  get showPlayerPrompt() {
    return this.isAdmin && !this.playerId && !this.isLoading;
  }

  get hasGames() {
    return this.gameSelections.length > 0;
  }

  get selectionSummary() {
    return `${this.numSelections} of ${this.numGames} selected`;
  }

  get hasIncompleteSelections() {
    return (
      !!this.playerId && this.hasGames && this.numSelections < this.numGames
    );
  }

  get incompleteSelectionsMessage() {
    const remaining = this.numGames - this.numSelections;
    return `Warning: you have only selected ${this.numSelections} of ${this.numGames} games. ${remaining} game${remaining === 1 ? "" : "s"} still need${remaining === 1 ? "s" : ""} a pick.`;
  }

  get isViewMode() {
    return this.mode === MODE_VIEW;
  }

  get modeLabel() {
    if (this.mode === MODE_PRIVILEGED_EDIT) {
      return "Editing (Locked Games Unlocked)";
    }
    if (this.mode === MODE_EDIT) {
      return "Editing";
    }
    return "Viewing";
  }

  get isEditDisabled() {
    return !(
      this.playerId &&
      this.isViewMode &&
      !(this.allLocked && !this.isAdmin)
    );
  }

  get isPrivilegedEditDisabled() {
    return !(this.isAdmin && this.playerId && this.isViewMode);
  }

  get isDoneDisabled() {
    return !(this.playerId && !this.isViewMode);
  }

  get isPrintableViewDisabled() {
    return !this.playerId;
  }

  handlePlayerChange(event) {
    this.playerId = event.detail.value;
    this.mode = MODE_VIEW;
  }

  handleWeekChange(event) {
    this.weekNumber = event.detail.value;
    this.mode = MODE_VIEW;
  }

  handleEdit() {
    this.mode = MODE_EDIT;
  }

  handlePrivilegedEdit() {
    this.showPrivilegedEditConfirm = true;
  }

  handleConfirmPrivilegedEdit() {
    this.showPrivilegedEditConfirm = false;
    this.mode = MODE_PRIVILEGED_EDIT;
  }

  handleCancelPrivilegedEdit() {
    this.showPrivilegedEditConfirm = false;
  }

  handleDone() {
    this.mode = MODE_VIEW;
  }

  handlePrintableView() {
    // Open the tab synchronously (within the click's user-gesture context) so
    // popup blockers don't intercept it, then navigate it once the VF page's
    // URL is resolved asynchronously via GenerateUrl.
    const printWindow = window.open("", "_blank");
    const params = new URLSearchParams();
    params.set("weekNumber", this.weekNumber || "");
    params.set("playerId", this.playerId || "");
    this[NavigationMixin.GenerateUrl]({
      type: "standard__webPage",
      attributes: {
        url: `/apex/PrintableSelections?${params.toString()}`
      }
    }).then((url) => {
      if (printWindow) {
        printWindow.location.href = url;
      }
    });
  }

  handleSelectionSaved() {
    refreshApex(this.selectionsResult);
  }

  reduceError(error) {
    if (error && error.body && error.body.message) {
      return error.body.message;
    }
    if (error && error.message) {
      return error.message;
    }
    return "An unknown error occurred while loading selections.";
  }
}
