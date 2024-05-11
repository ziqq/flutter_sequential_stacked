import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:l/l.dart';
import 'package:stacked/stacked.dart';

/// A observer that processes the logic, connects widgets and data.
class ViewModelObserver implements IViewModelObserver {
  @override
  void onCreate(BaseViewModel viewModel) {
    l.v6('Viewmodel | ${viewModel.runtimeType} | Created');
  }

  @override
  void onDispose(BaseViewModel viewModel) {
    l.v5('Viewmodel | ${viewModel.runtimeType} | Disposed');
  }

  @override
  void onStateChanged<S extends Object>(
    BaseViewModel viewModel,
    S prevState,
    S nextState,
  ) {
    l.d('ViewmodelState | ${viewModel.runtimeType} | $prevState -> $nextState');
  }

  @override
  void onError(BaseViewModel viewModel, Object error, StackTrace stackTrace) {
    l.w('Viewmodel | ${viewModel.runtimeType} | $error', stackTrace);
  }
}

void main() => runZonedGuarded<Future<void>>(() async {
      WidgetsFlutterBinding.ensureInitialized();
      SequentialViewModel.observer = ViewModelObserver();
      runApp(const SequentialStackedDemo());
    }, (error, stackTrace) {
      l.e('Error: $error, stackTrace: $stackTrace');
    });

/// Main app
class SequentialStackedDemo extends StatelessWidget {
  const SequentialStackedDemo({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Sequential Stacked Demo',
        theme: ThemeData.dark(),
        home: const SequentialStackedDemo$Screen(),
      );
}

/// Main screen
class SequentialStackedDemo$Screen extends StatelessWidget {
  const SequentialStackedDemo$Screen({super.key});

  @override
  Widget build(BuildContext context) =>
      ViewModelBuilder<SequentialStackedDemo$ScreenViewmodel>.reactive(
        viewModelBuilder: () => SequentialStackedDemo$ScreenViewmodel(),
        onViewModelReady: (model) => model.init(),
        builder: (context, model, _) => Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: const Text('Sequential Stacked Demo'),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'You have pushed the button this many times:',
                ),
                Text(
                  '${model.counter}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                onPressed: model.incrementCounter,
                tooltip: 'Increment',
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 16),
              FloatingActionButton(
                onPressed: model.dicrementCounter,
                tooltip: 'Dicrement',
                child: const Icon(Icons.remove),
              ),
            ],
          ),
        ),
      );
}

/// Main viewmodel
final class SequentialStackedDemo$ScreenViewmodel extends SequentialViewModel
    with DroppableViewModelHandler {
  int _counter = 0;
  int get counter => _counter;

  void init() => handle(() async {});

  void incrementCounter() => handle(() async {
        await Future<void>.delayed(const Duration(seconds: 3));
        _counter++;
        notifyListeners();
      });

  void dicrementCounter() => handle(() async {
        await Future<void>.delayed(const Duration(seconds: 3));
        _counter--;
        notifyListeners();
      });
}

/// The viewmodel responsible for processing the logic,
/// the connection of widgets and the date of the layer.
///
/// Do not implement this interface directly, instead extend [ViewModel].
abstract interface class IViewModel implements Listenable {
  /// Whether the controller is permanently disposed
  bool get isDisposed;

  /// Whether the controller is currently handling a requests
  bool get isProcessing;

  /// A future that completes when the controller is done processing.
  Future<void> get done;

  /// Discards any resources used by the object.
  ///
  /// This method should only be called by the object's owner.
  void dispose();
}

/// Viewmodel observer
abstract interface class IViewModelObserver {
  /// Called when the controller is created.
  void onCreate(BaseViewModel viewModel);

  /// Called when the viewModel is disposed.
  void onDispose(BaseViewModel viewModel);

  /// Called on any state change in the viewModel.
  void onStateChanged<S extends Object>(
    BaseViewModel viewModel,
    S prevState,
    S nextState,
  );

  /// Called on any error in the viewModel.
  void onError(
    BaseViewModel viewModel,
    Object error,
    StackTrace stackTrace,
  );
}

/// Sequential viewModel
abstract class SequentialViewModel extends ReactiveViewModel
    with IndexTrackingStateHelper
    implements IViewModel {
  SequentialViewModel() {
    runZonedGuarded<void>(
      () => SequentialViewModel.observer?.onCreate(this),
      (error, stackTrace) {/* ignore */},
    );
  }

  /// Controller observer
  static IViewModelObserver? observer;

  @override
  List<ListenableServiceMixin> get listenableServices => [];

  @override
  bool get isDisposed => _$isDisposed;
  bool _$isDisposed = false;

  /// Error handling callback
  @protected
  void onError(Object error, StackTrace stackTrace) => runZonedGuarded<void>(
        () => SequentialViewModel.observer?.onError(this, error, stackTrace),
        (error, stackTrace) {/* ignore */},
      );

  /// State change handler
  @protected
  Future<R?> handle<R>(Future<R> Function() handler);

  @protected
  @nonVirtual
  @override
  void notifyListeners() {
    if (isDisposed) {
      assert(false, 'A $runtimeType was already disposed.');
      return;
    }
    super.notifyListeners();
  }

  @override
  @mustCallSuper
  void dispose() {
    if (isDisposed) {
      assert(false, 'A $runtimeType was already disposed.');
      return;
    }
    _$isDisposed = true;
    runZonedGuarded<void>(
      () => SequentialViewModel.observer?.onDispose(this),
      (error, stackTrace) {/* ignore */},
    );
    super.dispose();
  }
}

base mixin DroppableViewModelHandler on SequentialViewModel {
  final _ViewModelEventQueue _eventQueue = _ViewModelEventQueue();

  @override
  @nonVirtual
  bool get isProcessing => _eventQueue.length > 0;

  @override
  Future<void> get done => _eventQueue._processing ?? SynchronousFuture<void>(null);

  /// Use this method to handle asynchronous logic inside the cubit.
  @override
  @protected
  @mustCallSuper
  Future<R?> handle<R extends Object?>(
    Future<R> Function() handler, [
    Future<void> Function(Object error, StackTrace stackTrace)? errorHandler,
    Future<void> Function()? doneHandler,
  ]) =>
      _eventQueue.push<R?>(
        () {
          final completer = Completer<R?>();
          // ignore: unused_element
          void emit() {
            if (isDisposed || anyObjectsBusy || completer.isCompleted) return;
            // super.emit(state);
            super.notifyListeners();
          }

          Future<void> onError(Object error, StackTrace stackTrace) async {
            try {
              super.onFutureError(error, stackTrace);
              if (isDisposed || anyObjectsBusy || completer.isCompleted) return;
              await errorHandler?.call(error, stackTrace);
            } on Object catch (error, stackTrace) {
              super.onFutureError(error, stackTrace);
            }
          }

          runZonedGuarded<void>(
            () async {
              if (isDisposed || anyObjectsBusy) return;
              R? result;
              try {
                result = await handler();
              } on Object catch (error, stackTrace) {
                await onError(error, stackTrace);
              } finally {
                try {
                  await doneHandler?.call();
                } on Object catch (error, stackTrace) {
                  super.onFutureError(error, stackTrace);
                }
                completer.complete(result);
              }
            },
            onError,
          );
          return completer.future;
        },
      ).catchError((_, __) => null);

  @override
  @mustCallSuper
  void dispose() {
    _eventQueue.close();
    super.dispose();
  }
}

/// A queue of events that are processed sequentially.
final class _ViewModelEventQueue {
  _ViewModelEventQueue();

  final DoubleLinkedQueue<_ViewModelTask<Object?>> _queue =
      DoubleLinkedQueue<_ViewModelTask<Object?>>();
  Future<void>? _processing;
  bool _isClosed = false;

  /// Event queue length.
  int get length => _queue.length;

  /// Push it at the end of the queue.
  Future<T> push<T>(Future<T> Function() fn) {
    final task = _ViewModelTask<T>(fn);
    _queue.add(task);
    _exec();
    return task.future;
  }

  /// Mark the queue as closed.
  /// The queue will be processed until it's empty.
  /// But all new and current events will be rejected with [WSClientClosed].
  Future<void> close() async {
    _isClosed = true;
    await _processing;
  }

  /// Execute the queue.
  /// @nodoc
  void _exec() => _processing ??= Future.doWhile(() async {
        final event = _queue.first;
        try {
          if (_isClosed) {
            event.reject(StateError('Controller\'s event queue are disposed'), StackTrace.current);
          } else {
            await event();
          }
        } on Object catch (error, stackTrace) {
          /* warning(
            error,
            stackTrace,
            'Error while processing event "${event.id}"',
          ); */
          Future<void>.sync(() => event.reject(error, stackTrace)).ignore();
        }
        _queue.removeFirst();
        final isEmpty = _queue.isEmpty;
        if (isEmpty) _processing = null;
        return !isEmpty;
      });
}

/// A task that is processed sequentially.
class _ViewModelTask<T> {
  /// @nodoc
  _ViewModelTask(Future<T> Function() fn)
      : _fn = fn,
        _completer = Completer<T>();

  /// @nodoc
  final Completer<T> _completer;

  /// @nodoc
  final Future<T> Function() _fn;

  /// @nodoc
  Future<T> get future => _completer.future;

  /// @nodoc
  Future<T> call() async {
    final result = await _fn();
    if (!_completer.isCompleted) {
      _completer.complete(result);
    }
    return result;
  }

  /// @nodoc
  void reject(Object error, [StackTrace? stackTrace]) {
    if (_completer.isCompleted) return;
    _completer.completeError(error, stackTrace);
  }
}
