// ignore_for_file: invalid_use_of_internal_member

part of '../change_notifier_provider.dart';

/// {@macro riverpod.providerrefbase}
abstract class ChangeNotifierProviderRef<NotifierT extends ChangeNotifier?>
    implements Ref<NotifierT> {
  /// The [ChangeNotifier] currently exposed by this provider.
  ///
  /// Cannot be accessed while creating the provider.
  NotifierT get notifier;
}

// ignore: subtype_of_sealed_class
/// {@template riverpod.ChangeNotifierprovider}
/// Creates a [ChangeNotifier] and exposes its current state.
///
/// This provider is used in combination with `package:state_notifier`.
///
/// Combined with [ChangeNotifier], [ChangeNotifierProvider] can be used to manipulate
/// advanced states, that would otherwise be difficult to represent with simpler
/// providers such as [Provider] or [FutureProvider].
///
/// For example, you may have a todo-list, where you can add and remove
/// and complete a todo.
/// Using [ChangeNotifier], you could represent such state as:
///
/// ```dart
/// class TodosNotifier extends ChangeNotifier<List<Todo>> {
///   TodosNotifier(): super([]);
///
///   void add(Todo todo) {
///     state = [...state, todo];
///   }
///
///   void remove(String todoId) {
///     state = [
///       for (final todo in state)
///         if (todo.id != todoId) todo,
///     ];
///   }
///
///   void toggle(String todoId) {
///     state = [
///       for (final todo in state)
///         if (todo.id == todoId) todo.copyWith(completed: !todo.completed),
///     ];
///   }
/// }
/// ```
///
/// Which you can then pass to a [ChangeNotifierProvider] like so:
///
/// ```dart
/// final todosProvider = ChangeNotifierProvider<TodosNotifier, List<Todo>>((ref) => TodosNotifier());
/// ```
///
/// And finally, you can interact with it inside your UI:
///
/// ```dart
/// Widget build(BuildContext context, WidgetRef ref) {
///   // rebuild the widget when the todo list changes
///   List<Todo> todos = ref.watch(todosProvider);
///
///   return ListView(
///     children: [
///       for (final todo in todos)
///         CheckboxListTile(
///            value: todo.completed,
///            // When tapping on the todo, change its completed status
///            onChanged: (value) => ref.read(todosProvider.notifier).toggle(todo.id),
///            title: Text(todo.description),
///         ),
///     ],
///   );
/// }
/// ```
/// {@endtemplate}
class ChangeNotifierProvider<NotifierT extends ChangeNotifier?>
    extends _ChangeNotifierProviderBase<NotifierT>
    with AlwaysAliveProviderBase<NotifierT> {
  /// {@macro riverpod.ChangeNotifierprovider}
  ChangeNotifierProvider(
    this._createFn, {
    super.name,
    super.from,
    super.argument,
    super.dependencies,
    super.debugGetCreateSourceHash,
  });

  /// {@macro riverpod.autoDispose}
  static const autoDispose = AutoDisposeChangeNotifierProviderBuilder();

  /// {@macro riverpod.family}
  static const family = ChangeNotifierProviderFamilyBuilder();

  final NotifierT Function(ChangeNotifierProviderRef<NotifierT> ref) _createFn;

  @override
  NotifierT _create(ChangeNotifierProviderElement<NotifierT> ref) {
    return _createFn(ref);
  }

  @override
  ChangeNotifierProviderElement<NotifierT> createElement() {
    return ChangeNotifierProviderElement<NotifierT>._(this);
  }

  @override
  late final AlwaysAliveRefreshable<NotifierT> notifier =
      _notifier<NotifierT>(this);

  /// {@template riverpod.overridewith}
  /// Override the provider with a new initialization function.
  ///
  /// This will also disable the auto-scoping mechanism, meaning that if the
  /// overridden provider specified `dependencies`, it will have no effect.
  ///
  /// The override must not specify a `dependencies`.
  ///
  /// Some common use-cases are:
  /// - testing, by replacing a service with a fake implementation, or to reach
  ///   a very specific state easily.
  /// - multiple environments, by changing the implementation of a class
  ///   based on the platform or other parameters.
  ///
  /// This function should be used in combination with `ProviderScope.overrides`
  /// or `ProviderContainer.overrides`:
  ///
  /// ```dart
  /// final myService = Provider((ref) => MyService());
  ///
  /// runApp(
  ///   ProviderScope(
  ///     overrides: [
  ///       // Replace the implementation of the provider with a different one
  ///       myService.overrideWithProvider((ref) {
  ///         ref.watch('other');
  ///         return MyFakeService(),
  ///       })),
  ///     ],
  ///     child: MyApp(),
  ///   ),
  /// );
  /// ```
  /// {@endtemplate}
  Override overrideWith(
    Create<NotifierT, ChangeNotifierProviderRef<NotifierT>> create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ChangeNotifierProvider<NotifierT>(
        create,
        from: from,
        argument: argument,
      ),
    );
  }
}

/// The element of [ChangeNotifierProvider].
class ChangeNotifierProviderElement<NotifierT extends ChangeNotifier?>
    extends ProviderElementBase<NotifierT>
    implements ChangeNotifierProviderRef<NotifierT> {
  ChangeNotifierProviderElement._(
    _ChangeNotifierProviderBase<NotifierT> super.provider,
  );

  @override
  NotifierT get notifier => _notifierNotifier.value;
  final _notifierNotifier = ProxyElementValueNotifier<NotifierT>();

  void Function()? _removeListener;

  @override
  void create({required bool didChangeDependency}) {
    final provider = this.provider as _ChangeNotifierProviderBase<NotifierT>;

    final notifierResult =
        _notifierNotifier.result = Result.guard(() => provider._create(this));

    // TODO test requireState, as ref.read(p) is expected to throw if notifier creation failed
    final notifier = notifierResult.requireState;

    setState(notifier);

    if (notifier != null) {
      void listener() => setState(notifier);
      notifier.addListener(listener);
      _removeListener = () => notifier.removeListener(listener);
    }
  }

  @override
  bool updateShouldNotify(NotifierT previous, NotifierT next) => true;

  @override
  void runOnDispose() {
    super.runOnDispose();

    _removeListener?.call();
    _removeListener = null;

    final notifier = _notifierNotifier.result?.stateOrNull;
    if (notifier != null) {
      // TODO test ChangeNotifier.dispose is guarded
      runGuarded(notifier.dispose);
    }
    _notifierNotifier.result = null;
  }

  @override
  void visitChildren({
    required void Function(ProviderElementBase<Object?> element) elementVisitor,
    required void Function(ProxyElementValueNotifier<Object?> element)
        notifierVisitor,
  }) {
    super.visitChildren(
      elementVisitor: elementVisitor,
      notifierVisitor: notifierVisitor,
    );
    notifierVisitor(_notifierNotifier);
  }
}

// ignore: subtype_of_sealed_class
/// The [Family] of [ChangeNotifierProvider].
class ChangeNotifierProviderFamily<NotifierT extends ChangeNotifier?, Arg>
    extends FamilyBase<ChangeNotifierProviderRef<NotifierT>, NotifierT, Arg,
        NotifierT, ChangeNotifierProvider<NotifierT>> {
  /// The [Family] of [ChangeNotifierProvider].
  ChangeNotifierProviderFamily(
    super.create, {
    super.name,
    super.dependencies,
  }) : super(providerFactory: ChangeNotifierProvider.new);

  /// {@macro riverpod.overridewith}
  Override overrideWith(
    NotifierT Function(ChangeNotifierProviderRef<NotifierT> ref, Arg arg)
        create,
  ) {
    return FamilyOverrideImpl<NotifierT, Arg,
        ChangeNotifierProvider<NotifierT>>(
      this,
      (arg) => ChangeNotifierProvider<NotifierT>(
        (ref) => create(ref, arg),
        from: from,
        argument: arg,
      ),
    );
  }
}
