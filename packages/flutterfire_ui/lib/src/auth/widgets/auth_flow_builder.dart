import 'package:flutterfire_ui/auth.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart'
    show AuthCredential, FirebaseAuth;
import 'package:flutterfire_ui_oauth/flutterfire_ui_oauth.dart';

import '../auth_controller.dart';
import '../auth_flow.dart';
import '../auth_state.dart';

typedef AuthFlowBuilderCallback<T extends AuthController> = Widget Function(
  BuildContext context,
  AuthState state,
  T ctrl,
  Widget? child,
);

typedef StateTransitionListener<T extends AuthController> = void Function(
  AuthState oldState,
  AuthState newState,
  T controller,
);

class AuthFlowBuilder<T extends AuthController> extends StatefulWidget {
  static final _flows = <Object, AuthFlow>{};

  static T? getController<T extends AuthController>(Object flowKey) {
    final flow = _flows[flowKey];
    if (flow == null) return null;
    return flow as T;
  }

  final Object? flowKey;
  final FirebaseAuth? auth;
  final AuthAction? action;
  final AuthProvider? provider;
  final AuthFlow? flow;
  final AuthFlowBuilderCallback<T>? builder;
  final Widget? child;
  final Function(AuthCredential credential)? onComplete;
  final StateTransitionListener<T>? listener;

  const AuthFlowBuilder({
    Key? key,
    this.flowKey,
    this.action,
    this.builder,
    this.onComplete,
    this.child,
    this.listener,
    this.provider,
    this.auth,
    this.flow,
  })  : assert(
          builder != null || child != null,
          'Either child or builder should be provided',
        ),
        super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _AuthFlowBuilderState createState() => _AuthFlowBuilderState<T>();
}

class _AuthFlowBuilderState<T extends AuthController>
    extends State<AuthFlowBuilder> {
  @override
  AuthFlowBuilder<T> get widget => super.widget as AuthFlowBuilder<T>;
  AuthFlowBuilderCallback<T> get builder => widget.builder ?? _defaultBuilder;

  AuthState? prevState;

  late AuthFlow flow;
  late AuthAction action;

  bool initialized = false;

  late AuthProvider provider = widget.provider ?? _createDefaultProvider();

  Widget _defaultBuilder(_, __, ___, ____) {
    return widget.child!;
  }

  @override
  void initState() {
    super.initState();
    provider.auth = widget.auth ?? FirebaseAuth.instance;

    flow = widget.flow ?? createFlow();

    if (widget.flowKey != null) {
      AuthFlowBuilder._flows[widget.flowKey!] = flow;

      flow.onDispose = () {
        AuthFlowBuilder._flows.remove(widget.flowKey);
      };
    }

    action = widget.action ??
        (flow.auth.currentUser != null ? AuthAction.link : AuthAction.signIn);

    flow.addListener(onFlowStateChanged);
    prevState = flow.value;
    initialized = true;
  }

  AuthProvider _createDefaultProvider() {
    switch (T) {
      case EmailAuthController:
        return EmailAuthProvider();
      case PhoneAuthController:
        return PhoneAuthProvider();
      default:
        throw Exception("Can't create $T provider");
    }
  }

  AuthFlow createFlow() {
    if (widget.flowKey != null) {
      final existingFlow = AuthFlowBuilder._flows[widget.flowKey!];
      if (existingFlow != null) {
        return existingFlow;
      }
    }

    final _provider = provider;

    if (_provider is EmailAuthProvider) {
      return EmailAuthFlow(
        provider: _provider,
        action: widget.action,
        auth: widget.auth,
      );
    } else if (_provider is EmailLinkAuthProvider) {
      return EmailLinkFlow(
        provider: _provider,
        auth: widget.auth,
      );
    } else if (_provider is OAuthProvider) {
      return OAuthFlow(
        provider: _provider,
        action: widget.action,
        auth: widget.auth,
      );
    } else if (_provider is PhoneAuthProvider) {
      return PhoneAuthFlow(
        provider: _provider,
        action: widget.action,
        auth: widget.auth,
      );
    } else if (_provider is UniversalEmailSignInProvider) {
      return UniversalEmailSignInFlow(
        provider: _provider,
        action: widget.action,
        auth: widget.auth,
      );
    } else {
      throw Exception('Unknown provider $_provider');
    }
  }

  void onFlowStateChanged() {
    AuthStateTransition(prevState!, flow.value, flow as T).dispatch(context);
    widget.listener?.call(prevState!, flow.value, flow as T);
    prevState = flow.value;
  }

  @override
  void didUpdateWidget(covariant AuthFlowBuilder<AuthController> oldWidget) {
    flow.action = widget.action ?? action;
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return AuthControllerProvider(
      action: flow.action,
      ctrl: flow,
      child: ValueListenableBuilder<AuthState>(
        valueListenable: flow,
        builder: (context, value, _) {
          final child = builder(
            context,
            value,
            flow as T,
            widget.child,
          );

          return AuthStateProvider(state: value, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    flow.removeListener(onFlowStateChanged);

    if (widget.flowKey == null && widget.flow == null) {
      flow.reset();
    }

    super.dispose();
  }
}
