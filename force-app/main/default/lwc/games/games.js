import { LightningElement, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import getSettings from "@salesforce/apex/SettingsService.getSettings";
import getWeekNumbers from "@salesforce/apex/SettingsService.getWeekNumbers";
import getTeamOptions from "@salesforce/apex/GameService.getTeamOptions";
import getGamesForWeek from "@salesforce/apex/GameService.getGamesForWeek";
import saveGames from "@salesforce/apex/GameService.saveGames";
import deleteGame from "@salesforce/apex/GameService.deleteGame";

const NONE_TEAM_OPTION = { label: "-- None --", value: "" };
const MODE_VIEW = "view";
const MODE_EDIT = "edit";
const MODE_EDIT_LOCKED = "edit-locked";

const NUMERIC_FIELDS = new Set(["Home_Score__c", "Visiting_Score__c", "Spread__c"]);
const CHECKBOX_FIELDS = new Set(["Final__c"]);
const LOOKUP_FIELDS = new Set(["Home_Team__c", "Visiting_Team__c"]);

export default class Games extends LightningElement {
  weekNumber;
  currentWeek;
  maxGames = 0;
  allWeekNumbers = [];
  teamOptions = [NONE_TEAM_OPTION];

  mode = MODE_VIEW;
  games = [];
  numGamesToAdd = "1";

  isLoading = false;
  isSaving = false;
  loadError;
  errorLines = [];

  showPrivilegedEditConfirm = false;

  @wire(getSettings)
  wiredSettings({ data }) {
    if (data && data.CurrentWeek__c != null) {
      this.currentWeek = data.CurrentWeek__c;
      this.maxGames = data.MaxGames__c;
      if (!this.weekNumber) {
        this.weekNumber = String(data.CurrentWeek__c);
        this.loadGames();
      }
    }
  }

  @wire(getWeekNumbers)
  wiredWeekNumbers({ data, error }) {
    if (data) {
      this.allWeekNumbers = data;
    } else if (error) {
      this.allWeekNumbers = [];
    }
  }

  @wire(getTeamOptions)
  wiredTeamOptions({ data, error }) {
    if (data) {
      this.teamOptions = [NONE_TEAM_OPTION, ...data];
    } else if (error) {
      this.teamOptions = [NONE_TEAM_OPTION];
    }
  }

  // Lightning App Page tabs can stay mounted in the background when the user
  // navigates away, so connectedCallback/@wire won't naturally re-fire on
  // return. Unlike Selections/Results, only auto-refresh while in view mode —
  // refetching unconditionally would silently discard an admin's in-progress
  // edits if they tab away mid-edit.
  @wire(CurrentPageReference)
  handleCurrentPageReference(pageReference) {
    if (pageReference && this.isViewMode && this.weekNumber) {
      this.loadGames();
    }
  }

  async loadGames() {
    if (!this.weekNumber) {
      return;
    }
    this.isLoading = true;
    this.loadError = undefined;
    try {
      this.games = await getGamesForWeek({ weekNumber: this.weekNumber });
    } catch (error) {
      this.loadError = this.reduceError(error);
      this.games = [];
    } finally {
      this.isLoading = false;
    }
  }

  get isViewMode() {
    return this.mode === MODE_VIEW;
  }

  get isEditLockedMode() {
    return this.mode === MODE_EDIT_LOCKED;
  }

  get modeLabel() {
    if (this.mode === MODE_EDIT_LOCKED) {
      return "Editing (Locked Games Unlocked)";
    }
    if (this.mode === MODE_EDIT) {
      return "Editing";
    }
    return "Viewing";
  }

  get weekOptions() {
    return (this.allWeekNumbers || []).map((week) => ({
      label: `Week ${week}`,
      value: week
    }));
  }

  get gameCount() {
    return this.games.length;
  }

  get isAddDisabled() {
    return this.isViewMode || this.gameCount >= this.maxGames;
  }

  get numGameOptions() {
    const remaining = Math.max(this.maxGames - this.gameCount, 0);
    const options = [];
    for (let i = 1; i <= remaining; i++) {
      options.push({ label: String(i), value: String(i) });
    }
    return options;
  }

  get isNumGamesSelectDisabled() {
    return this.isAddDisabled || this.numGameOptions.length === 0;
  }

  get isEditDisabled() {
    return !this.isViewMode;
  }

  get isEditLockedDisabled() {
    return !this.isViewMode;
  }

  get isSaveDisabled() {
    return this.isViewMode || this.isSaving;
  }

  get isCancelDisabled() {
    return this.isViewMode;
  }

  get gameRows() {
    const lockGated = (isLocked) =>
      !this.isViewMode && (this.isEditLockedMode || !isLocked);
    const scoreEditable = !this.isViewMode;
    return this.games.map((wrapper, index) => ({
      key: wrapper.game.Id || `new-${index}`,
      index,
      gameNumber: wrapper.gameNumber,
      game: wrapper.game,
      isLocked: wrapper.isLocked,
      isStartTimeEditable: lockGated(wrapper.isLocked),
      isHomeTeamEditable: lockGated(wrapper.isLocked),
      isVisitingTeamEditable: lockGated(wrapper.isLocked),
      isSpreadEditable: lockGated(wrapper.isLocked),
      isScoreEditable: scoreEditable,
      isFinalEditable: scoreEditable,
      isFinalDisabled: !scoreEditable,
      showWinner: this.isViewMode,
      isDeleteVisible: this.isEditLockedMode,
      isDeleteDisabled: wrapper.game.Final__c === true,
      homeTeamName: wrapper.game.Home_Team__r ? wrapper.game.Home_Team__r.Name : "",
      visitingTeamName: wrapper.game.Visiting_Team__r
        ? wrapper.game.Visiting_Team__r.Name
        : "",
      homeTeamOptions: this.buildTeamOptions(wrapper.game.Home_Team__c),
      visitingTeamOptions: this.buildTeamOptions(wrapper.game.Visiting_Team__c)
    }));
  }

  // A <select value={...}> binding is unreliable when its <option>
  // children come from for:each -- the value gets applied before the
  // options exist in the DOM. Compute the selected option explicitly per
  // row instead and bind `selected` on each <option>.
  buildTeamOptions(selectedId) {
    const normalizedSelected = selectedId || "";
    return this.teamOptions.map((option) => ({
      value: option.value,
      label: option.label,
      selected: option.value === normalizedSelected
    }));
  }

  get hasGames() {
    return this.games.length > 0;
  }

  get hasErrorLines() {
    return this.errorLines && this.errorLines.length > 0;
  }

  handleWeekChange(event) {
    const newWeek = event.detail.value;
    if (!this.isViewMode) {
      // eslint-disable-next-line no-alert
      const ok = window.confirm(
        "WARNING! You have unsaved changes. Clicking OK will discard them and load the selected week. Click Cancel to stay on this week."
      );
      if (!ok) {
        const combobox = this.template.querySelector(".games__week-picker");
        if (combobox) {
          combobox.value = this.weekNumber;
        }
        return;
      }
    }
    this.weekNumber = newWeek;
    this.mode = MODE_VIEW;
    this.errorLines = [];
    this.loadGames();
  }

  handleEdit() {
    this.mode = MODE_EDIT;
  }

  handleEditLocked() {
    this.showPrivilegedEditConfirm = true;
  }

  handleConfirmPrivilegedEdit() {
    this.showPrivilegedEditConfirm = false;
    this.mode = MODE_EDIT_LOCKED;
  }

  handleCancelPrivilegedEdit() {
    this.showPrivilegedEditConfirm = false;
  }

  handleNumGamesToAddChange(event) {
    this.numGamesToAdd = event.detail.value;
  }

  handleAddSingleGame() {
    this.addGamesToList(1);
  }

  handleAddMultipleGames() {
    this.addGamesToList(Number(this.numGamesToAdd) || 1);
  }

  addGamesToList(count) {
    const blanks = [];
    for (let i = 0; i < count; i++) {
      blanks.push({ game: { Week__c: this.weekNumber }, isLocked: false, gameNumber: 0 });
    }
    this.games = this.renumber([...this.games, ...blanks]);
    // Unlike the old VF page (which always dropped back to plain "edit"),
    // stay in edit-locked mode if already there, so adding a game doesn't
    // silently lose the lock-override on other in-progress rows.
    if (!this.isEditLockedMode) {
      this.mode = MODE_EDIT;
    }
    this.numGamesToAdd = "1";
  }

  renumber(list) {
    return list.map((wrapper, index) => ({ ...wrapper, gameNumber: index + 1 }));
  }

  extractFieldValue(field, detail) {
    if (CHECKBOX_FIELDS.has(field)) {
      return detail.checked;
    }
    if (NUMERIC_FIELDS.has(field)) {
      return detail.value === "" || detail.value == null ? null : Number(detail.value);
    }
    if (LOOKUP_FIELDS.has(field)) {
      return detail.value === "" ? null : detail.value;
    }
    return detail.value;
  }

  applyFieldChange(index, field, value) {
    this.games = this.games.map((wrapper, i) => {
      if (i !== index) {
        return wrapper;
      }
      return { ...wrapper, game: { ...wrapper.game, [field]: value } };
    });
  }

  handleTableFieldChange(event) {
    const index = Number(event.currentTarget.dataset.index);
    const field = event.currentTarget.dataset.field;
    // Home/Visiting Team use a native <select> (for native type-ahead
    // cycling, which lightning-combobox doesn't support), so it fires a
    // plain DOM change event with no .detail -- read .target.value instead.
    const detail = LOOKUP_FIELDS.has(field)
      ? { value: event.target.value }
      : event.detail;
    this.applyFieldChange(index, field, this.extractFieldValue(field, detail));
  }

  handleCardFieldChange(event) {
    const { index, field, detail } = event.detail;
    this.applyFieldChange(index, field, this.extractFieldValue(field, detail));
  }

  handleTableDeleteClick(event) {
    const index = Number(event.currentTarget.dataset.index);
    this.confirmAndDeleteGame(index);
  }

  handleCardDeleteGame(event) {
    this.confirmAndDeleteGame(event.detail.index);
  }

  async confirmAndDeleteGame(index) {
    const wrapper = this.games[index];
    if (!wrapper) {
      return;
    }
    // eslint-disable-next-line no-alert
    const ok = window.confirm(
      "Are you sure you want to delete this game? Click OK to delete, or Cancel to continue editing."
    );
    if (!ok) {
      return;
    }
    if (wrapper.game.Id) {
      try {
        await deleteGame({ gameId: wrapper.game.Id, weekNumber: this.weekNumber });
      } catch (error) {
        this.errorLines = this.reduceErrorLines(error);
        return;
      }
    }
    // Splice locally rather than adopting deleteGame's full-week response,
    // so unsaved edits on other rows aren't silently discarded.
    this.games = this.renumber(this.games.filter((_, i) => i !== index));
  }

  async handleSave() {
    await this.persistGames(true);
  }

  async handleQuickSave() {
    await this.persistGames(false);
  }

  async persistGames(returnToView) {
    this.isSaving = true;
    this.errorLines = [];
    try {
      const payload = this.games.map((wrapper) => wrapper.game);
      this.games = await saveGames({ games: payload });
      if (returnToView) {
        this.mode = MODE_VIEW;
      }
    } catch (error) {
      this.errorLines = this.reduceErrorLines(error);
    } finally {
      this.isSaving = false;
    }
  }

  handleCancel() {
    this.mode = MODE_VIEW;
    this.errorLines = [];
    this.loadGames();
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

  reduceErrorLines(error) {
    return this.reduceError(error)
      .split("\n")
      .filter((line) => line.length > 0);
  }
}
