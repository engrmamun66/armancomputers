<template>
  <input
    ref="inputElement"
    type="text"
    :class="classes"
    :style="style"
    :disabled="isDisabled"
  />
</template>

<script setup>
import { ref, watch, onMounted, defineEmits, useAttrs, computed, inject } from "vue";
let moment = inject('moment')

let props = defineProps({
  classes: {
    default: "form-control",
    requird: false,
  },
  modelValue: {
    default: "",
    requird: true,
  },
  modelValueType: {
    default: "string",
    requird: true,
  },
  style: {
    default: "",
    default: "string",
    requird: true,
  },
  isDisabled: {
    default: false,
    requird: false,
  },
  fireNextPrevOnMount: {
    default: false,
    requird: false,
  },
  est_valid_dates: {
    default: [
      /**
       * {
       *  start: 'YYY-MM-DD',
       *  end: 'YYY-MM-DD',
       * }
       * ...
       */
    ],
    requird: false,
  },
});

let emits = defineEmits(["update:modelValue", "change", "nextPrev", "opening"]);


watch(()=> props.isDisabled, (nVal, oVal) => {
  inputElement.value.emDateTimePicker("is_disabled", nVal);
})

let inputElement = ref(null);
let isReady = ref(false);

// The engine has no built-in reactive modelValue->picker sync (it's imperative,
// driven by its own DOM-attribute-based init + set_date/set_date_time calls). This
// fills that gap so v-model keeps working when a parent loads data asynchronously
// (e.g. an edit form) after this component has already mounted and initialized.
watch(() => props.modelValue, (value) => {
  if (!isReady.value || !value || !inputElement.value?.emDateTimePicker) return;
  if (props.modelValueType === "date") {
    inputElement.value.emDateTimePicker("set_date", value);
  }
});
const attrs = useAttrs();
const pickerAttrs = computed(() => {
  const out = { ...attrs, is_disabled: props.isDisabled };
  const aliasMap = {
    "range-picker": "rangePicker",
    "time-picker": "timePicker",
    "min-date": "minDate",
    "start-date": "startDate",
    "display-format": "displayFormat",
    "auto-open": "autoOpen",
    "time-picker-buttons": "timePickerButtons",
    "time-picker-ui": "timePickerUi",
    "use24-format-time-for-events": "use24FormatTimeForEvents",
    "adjust-x": "adjustX",
    "adjust-y": "adjustY",
    "use24-format": "use24Format",
    "display-in": "displayIn",
    "is-disabled": "isDisabled",
    "keep-empty-the-calendar-first": "keepEmptyTheCalendarFirst",
  };

  Object.keys(aliasMap).forEach((key) => {
    if (key in out && !(aliasMap[key] in out)) {
      out[aliasMap[key]] = out[key];
    }
  });
  return out;
});



function makeDatesObject(start = '2025-04-15', end = '2025-04-15') {
  const dateArray = {}; // Array to store the dates
  let currentDate = moment(start); // Start date
  const endDate = moment(end); // End date

  while (currentDate.isSameOrBefore(endDate)) {
      dateArray[currentDate.format('YYYY-MM-DD')] = true
      currentDate.add(1, 'day');
  }
  return dateArray;
}






onMounted(() => {
  inputElement.value.addEventListener("click", () => {
    inputElement.value.emDateTimePicker(
      "set_available_in_dates",
      props.availableList
    );
  });
  if(inputElement.value?.emDateTimePicker){
    inputElement.value
      .emDateTimePicker({
        ...pickerAttrs.value,
      })
      .onEvent("initialized", (data) => {
        isReady.value = true;
        if (props.modelValue && props.modelValueType === "date") {
          inputElement.value.emDateTimePicker("set_date", props.modelValue);
        }
        if(props.fireNextPrevOnMount){
          setTimeout(() => {
            inputElement.value.triggerEvent('next')
          }, 100);
          setTimeout(() => {
            inputElement.value.triggerEvent('prev')
          }, 200);
        }
      })
      .onEvent("open", (data) => {
        emits('opening', true)
      })
      .onEvent("change_date", (data) => {
        emits("change", data);

        if (props.modelValueType === "date") {
          emits("update:modelValue", data.startDateTime);
        } else if (props.modelValueType === "string") {
          emits(
            "update:modelValue",
            `${data.startDateTime} - ${data.endDateTime}`
          );
        } else {
          emits("update:modelValue", data);
        }
      })
      .onEvent("next_prev", ({ startDateOfMonth, endDateOfMonth, startDateOfCalendar, endDateOfCalendar }) => {
        emits("nextPrev", {
          start_date: startDateOfMonth,
          end_date: endDateOfMonth,
        });


      });
  }
});

defineExpose({
  target: inputElement.value,
  toggle: function () {
    inputElement.value.click();
  },
  setDate: function (...args) {
    inputElement.value.emDateTimePicker("set_date", ...args);
  },
  setDateTime: function (...args) {
      inputElement.value.emDateTimePicker("set_date_time", ...args);
  },
  setTime: function (...args) {
    inputElement.value.emDateTimePicker("set_time", ...args);
  },
  triggerChange: function (eventName = "change_date") {
    inputElement.value.triggerEvent(eventName);
  },
  setAvailableDates: function (data) {
    if (!data || !data?.length) return;
    inputElement.value.emDateTimePicker("set_available_in_dates", data);
  },
  updateOptions: function (options) {
    inputElement.value.emDateTimePicker("update_options", options);
  },
  makeDisable: function (boolean = true) {
    inputElement.value.emDateTimePicker("is_disabled", boolean);
  },
});
</script>
