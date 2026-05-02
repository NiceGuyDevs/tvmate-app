import 'package:flutter/material.dart';

import '../../data/library_controller.dart';
import '../../data/parental_control_store.dart';
import '../settings/parental_pin_dialog.dart';

Future<bool> ensureParentalAllowsLivePlayback(
  BuildContext context, {
  required String viewCategoryId,
  required String channelId,
  required String channelCategoryId,
}) async {
  await parentalControlStore.ensureLoaded();
  final pid = libraryController.activePlaylistId;
  if (!parentalControlStore.isLivePlaybackBlocked(
    playlistId: pid,
    viewCategoryId: viewCategoryId,
    channelId: channelId,
    channelCategoryId: channelCategoryId,
  )) {
    return true;
  }
  if (!context.mounted) return false;
  return showParentalPinVerifyDialog(context);
}

Future<bool> ensureParentalAllowsMoviePlayback(
  BuildContext context, {
  required String movieId,
  required String categoryId,
}) async {
  await parentalControlStore.ensureLoaded();
  final pid = libraryController.activePlaylistId;
  if (!parentalControlStore.isMoviePlaybackBlocked(
    playlistId: pid,
    movieId: movieId,
    categoryId: categoryId,
  )) {
    return true;
  }
  if (!context.mounted) return false;
  return showParentalPinVerifyDialog(context);
}

Future<bool> ensureParentalAllowsSeriesPlayback(
  BuildContext context, {
  required String seriesId,
  required String categoryId,
}) async {
  await parentalControlStore.ensureLoaded();
  final pid = libraryController.activePlaylistId;
  if (!parentalControlStore.isSeriesPlaybackBlocked(
    playlistId: pid,
    seriesId: seriesId,
    categoryId: categoryId,
  )) {
    return true;
  }
  if (!context.mounted) return false;
  return showParentalPinVerifyDialog(context);
}
