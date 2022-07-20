import 'dart:async';
import 'dart:math';
import 'package:Reminder/src/core/util/extensions.dart';
import 'package:Reminder/src/service/alarm_manager.dart';
import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/general_constant.dart';
import '../../data/local/object_box_helper.dart';
import '../../data/model/notification_scheduler_model.dart';

part 'set_notify_event.dart';

part 'set_notify_state.dart';

class SetNotifyBloc extends Bloc<SetNotifyEvent, SetNotifyState> {
  final TextEditingController _controller = TextEditingController();
  late Jalali selectedJalaliDateTime;
  late TimeOfDay endTimeOfDay;
  late TimeOfDay startTimeOfDay;
  ObjectBoxHelper objectBoxHelper;
  late List<NotificationSchedulerModel> notificationSchedulers;

  SetNotifyBloc({required this.objectBoxHelper})
      : super(SetNotifyInitial()) {
    on<SetNotifyStarted>(_onStarted);
    on<SetNotifySelectDateAndTimeClicked>(_onSelectDateAndTimeClicked);
    on<SetNotifyUpdatedEvent>(_onUpdated);
    on<SetNotifyReminerDisabledEvent>(_onDisabled);
    on<SetNotifyDateAndTimeTakenEvent>(_onDateAndTimeTaken);
    on<SetNotifyReminderCountTaken>(_onReminderCountTaken);
  }

  _onStarted(SetNotifyStarted event, Emitter<SetNotifyState> emit) async {
    await objectBoxHelper.init();
    await Future.delayed(const Duration(milliseconds: 500));
    notificationSchedulers = objectBoxHelper.getDateAndTimes();
    emit(SetNotifySuccess(
        notificationSchedulersList: notificationSchedulers));
  }

  _onUpdated(SetNotifyUpdatedEvent event, Emitter<SetNotifyState> emit) {
    emit(SetNotifyUpdate(
        notificationSchedulersList: event.notificationSchedulers));
  }

  _onDisabled(SetNotifyReminerDisabledEvent event, Emitter<SetNotifyState> emit) async {
    notificationSchedulers[event.notificationSchedulerIndex].isActive = false;
    add(SetNotifyUpdatedEvent(notificationSchedulers: notificationSchedulers));
    await Future.delayed(const Duration(milliseconds: 200));
    await cancelAlarmManager(
        alarmId: notificationSchedulers[event.notificationSchedulerIndex].id);
    objectBoxHelper.deleteTime(
        notificationSchedulers[event.notificationSchedulerIndex].id);
    notificationSchedulers.removeAt(event.notificationSchedulerIndex);
    add(SetNotifyUpdatedEvent(notificationSchedulers: notificationSchedulers));
  }

  _onSelectDateAndTimeClicked(SetNotifySelectDateAndTimeClicked event,
      Emitter<SetNotifyState> emit) async {
    emit(SetNotifyShowDateAndTimePicker());
  }

   _onDateAndTimeTaken(SetNotifyDateAndTimeTakenEvent event, Emitter<SetNotifyState> emit) {
    selectedJalaliDateTime = event.selectedJalaliDateTime;
    startTimeOfDay=event.startTimeOfDay;
    endTimeOfDay=event.endTimeOfDay;

     if (_isEndTimeOfDayAfterStartTimeOfDay(selectedJalaliDateTime,startTimeOfDay,endTimeOfDay)) {
       emit(SetNotifyShowEnterNotificationCountDialog(textEditingController: _controller));
     } else {
       emit(SetNotifyShowSnackBar());

     }
  }

   _onReminderCountTaken(SetNotifyReminderCountTaken event, Emitter<SetNotifyState> emit) async {

     NotificationSchedulerModel notificationScheduler =
         await _generateRandomTimesAndSaveThem(event.reminderCount);

     await setAlarmManager(
         millisecondsSinceEpoch: int.tryParse(
         notificationScheduler.dateTimesMillisecondsSinceEpoch.first)!,
     alarmId: notificationScheduler.id);

     notificationSchedulers.add(notificationScheduler);
     add(SetNotifyUpdatedEvent(notificationSchedulers: notificationSchedulers));
  }

  bool _isEndTimeOfDayAfterStartTimeOfDay(Jalali selectedJalaliDateTime,TimeOfDay startTimeOfDay,TimeOfDay endTimeOfDay) {
    return endTimeOfDay.isAfter(startTimeOfDay);
  }

  Future<NotificationSchedulerModel> _generateRandomTimesAndSaveThem(
      int count) async {
    Random random = Random();

    double doubleEndToMinute =
        endTimeOfDay.hour.toDouble() + (endTimeOfDay.minute.toDouble() / 60);
    double doubleStarToMinute = startTimeOfDay.hour.toDouble() +
        (startTimeOfDay.minute.toDouble() / 60);

    double interval = (doubleEndToMinute - doubleStarToMinute);

    Set<double> generatedRandomMinutesSet = <double>{};
    while (generatedRandomMinutesSet.length < count) {
      double randomTimeOfDay = random.nextDouble() * interval;
      if (randomTimeOfDay > (kMinimumInterval / 60)) {
        generatedRandomMinutesSet.add(randomTimeOfDay);
      }
    }

    //convert set to list for sort
    List<double> generatedRandomMinutesList =
    generatedRandomMinutesSet.toList();
    generatedRandomMinutesList.sort();

    //create list for convert generated random values to dateTime
    List<String> millisecondSinceEpoch = [];

    for (int i = 0; i < generatedRandomMinutesList.length; i++) {
      int hour = (generatedRandomMinutesList[i]).truncate();
      int minute = ((generatedRandomMinutesList[i] - hour) * 60).toInt();

      millisecondSinceEpoch.add((DateTime(
          selectedJalaliDateTime.toDateTime().year,
          selectedJalaliDateTime.toDateTime().month,
          selectedJalaliDateTime.toDateTime().day,
          startTimeOfDay.hour + hour,
          startTimeOfDay.minute + minute)
          .millisecondsSinceEpoch)
          .toString());
    }

    DateTime notificationSchedulerId = DateTime(
        selectedJalaliDateTime.toDateTime().year,
        selectedJalaliDateTime.toDateTime().month,
        selectedJalaliDateTime.toDateTime().day,
        0,
        0);

    DateTime startDateTime = DateTime(
        selectedJalaliDateTime.toDateTime().year,
        selectedJalaliDateTime.toDateTime().month,
        selectedJalaliDateTime.toDateTime().day,
        startTimeOfDay.hour,
        startTimeOfDay.minute);

    DateTime endDateTime = DateTime(
        selectedJalaliDateTime.toDateTime().year,
        selectedJalaliDateTime.toDateTime().month,
        selectedJalaliDateTime.toDateTime().day,
        endTimeOfDay.hour,
        endTimeOfDay.minute);

    NotificationSchedulerModel notificationSchedulerModel =
    NotificationSchedulerModel(
        id: notificationSchedulerId.millisecondsSinceEpoch ~/ 10000,
        dateTimesMillisecondsSinceEpoch: millisecondSinceEpoch,
        startDateTime: startDateTime,
        endDateTime: endDateTime);

    objectBoxHelper.put(notificationSchedulerModel);
    return notificationSchedulerModel;
  }

  @override
  Future<void> close() {
    _controller.dispose();
    objectBoxHelper.close();
    return super.close();
  }
}
