import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/models.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart' hide ServiceStatus;
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/places_service.dart';

class ServiceModal extends StatefulWidget {
  const ServiceModal({super.key});

  @override
  State<ServiceModal> createState() => _ServiceModalState();
}

class _ServiceModalState extends State<ServiceModal> {
  final _serviceTypeCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _dateCtrl = TextEditingController(); // AAAA-MM-DD
  final _timeCtrl = TextEditingController(); // HH:MM
  final _addressCtrl = TextEditingController();

  final List<String> _selectedTeamIds = [];
  List<UserModel> _allUsers = [];
  double? _lat;
  double? _lng;
  bool _gpsLoading = false;
  bool _showMap = false;

  // Places autocomplete
  final PlacesService _places = PlacesService();
  List<PlacePrediction> _predictions = [];
  bool _searchingPlaces = false;
  GoogleMapController? _mapController;

  // Overlay dropdown
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _addressRowKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  // Scroll para revelar o mapa automaticamente
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _addressCtrl.addListener(_onAddressChanged);
  }

  @override
  void dispose() {
    _addressCtrl.removeListener(_onAddressChanged);
    _addressCtrl.dispose();
    _serviceTypeCtrl.dispose();
    _departmentCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _mapController?.dispose();
    _places.dispose();
    _scrollCtrl.dispose();
    _removeOverlay();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final authProvider = context.read<AuthProvider>();
    final me = authProvider.currentUser;
    final users = await authProvider.getAllUsers();
    if (mounted) {
      setState(() => _allUsers = users.where((u) {
            // Apenas colaboradores cujo managerId aponta para o gestor logado
            if (me != null &&
                (me.role == UserRole.GESTOR || me.role == UserRole.MANAGER)) {
              return u.managerId == me.id &&
                  u.role == UserRole.EMPLOYEE &&
                  u.status == UserStatus.ACTIVE;
            }
            // Outros papéis (GENERAL_MANAGER, SECRETARY) veem todos ativos
            return (u.role == UserRole.GESTOR ||
                    u.role == UserRole.SECRETARY ||
                    u.role == UserRole.EMPLOYEE) &&
                u.status == UserStatus.ACTIVE;
          }).toList());
    }
  }

  // ─── Overlay dropdown ────────────────────────────────────────────────────
  void _showSuggestionsOverlay() {
    _removeOverlay();
    if (_predictions.isEmpty) return;
    final box = _addressRowKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 300.0;
    final rowHeight = box?.size.height ?? 58.0;
    _overlayEntry = OverlayEntry(
      builder: (ctx) => CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: Offset(0, rowHeight + 2),
        child: Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: width,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: _predictions
                      .map(
                        (p) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined, size: 18),
                          title: Text(p.description,
                              style: const TextStyle(fontSize: 13)),
                          onTap: () => _selectPrediction(p),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // ─── Autocomplete ────────────────────────────────────────────────────────
  void _onAddressChanged() {
    final text = _addressCtrl.text;
    if (text.length < 3) {
      if (_predictions.isNotEmpty) {
        setState(() => _predictions = []);
        _removeOverlay();
      }
      return;
    }
    _fetchPredictions(text);
  }

  Future<void> _fetchPredictions(String input) async {
    setState(() => _searchingPlaces = true);
    final results = await _places.autocomplete(input);
    if (mounted) {
      setState(() {
        _predictions = results;
        _searchingPlaces = false;
      });
      _showSuggestionsOverlay();
    }
  }

  Future<void> _selectPrediction(PlacePrediction p) async {
    // Fill address text without triggering listener
    _addressCtrl.removeListener(_onAddressChanged);
    _addressCtrl.text = p.description;
    _addressCtrl.addListener(_onAddressChanged);

    setState(() => _predictions = []);
    _removeOverlay();

    final detail = await _places.getDetails(p.placeId);
    // ignore: avoid_print
    print('[ServiceModal] getDetails result: $detail');
    if (detail != null && mounted) {
      setState(() {
        _lat = detail.lat;
        _lng = detail.lng;
        _showMap = true;
      });
      // Scroll para revelar o mapa
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(detail.lat, detail.lng), 16),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Não foi possível obter a localização do endereço.')),
      );
    }
  }

  // ─── GPS ─────────────────────────────────────────────────────────────────
  Future<void> _captureGPS() async {
    _removeOverlay();
    setState(() {
      _gpsLoading = true;
      _predictions = [];
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ative o GPS do dispositivo.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permissão de localização negada.')),
            );
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Permissão negada permanentemente. Habilite nas configurações.'),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _showMap = true;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude), 16),
      );

      // Reverse geocode to fill address
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks.first;
          final parts = [
            place.street,
            place.subLocality,
            place.locality,
            place.administrativeArea,
          ].where((p) => p != null && p.isNotEmpty).join(', ');
          _addressCtrl.removeListener(_onAddressChanged);
          setState(() {
            _addressCtrl.text = parts;
            _predictions = [];
          });
          _addressCtrl.addListener(_onAddressChanged);
        }
      } catch (_) {
        if (mounted) {
          _addressCtrl.removeListener(_onAddressChanged);
          _addressCtrl.text =
              '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
          _addressCtrl.addListener(_onAddressChanged);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao capturar localização: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        controller: _scrollCtrl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Criar Novo Serviço em Andamento',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _serviceTypeCtrl,
              decoration:
                  const InputDecoration(labelText: 'Descrição/Nome do Serviço'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _departmentCtrl,
              decoration:
                  const InputDecoration(labelText: 'Departamento Destino'),
            ),
            const SizedBox(height: 10),

            // ── Endereço + GPS ──────────────────────────────────────────────
            CompositedTransformTarget(
              link: _layerLink,
              child: Row(
                key: _addressRowKey,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addressCtrl,
                      decoration: InputDecoration(
                        labelText: 'Endereço / Local do Serviço',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        suffixIcon: _lat != null
                            ? const Icon(Icons.verified_outlined,
                                color: Colors.green, size: 18)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 56,
                    child: Tooltip(
                      message: 'Capturar localização GPS',
                      child: IconButton.filled(
                        onPressed: _gpsLoading ? null : _captureGPS,
                        icon: _gpsLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.my_location),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_searchingPlaces)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: LinearProgressIndicator(),
              ),

            // ── Mapa embutido ───────────────────────────────────────────────
            if (_showMap && _lat != null && _lng != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 200,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_lat!, _lng!),
                      zoom: 16,
                    ),
                    onMapCreated: (c) => _mapController = c,
                    markers: {
                      Marker(
                        markerId: const MarkerId('local'),
                        position: LatLng(_lat!, _lng!),
                        infoWindow: InfoWindow(
                            title: _addressCtrl.text.isNotEmpty
                                ? _addressCtrl.text
                                : 'Local do Serviço'),
                      ),
                    },
                    onTap: (pos) {
                      setState(() {
                        _lat = pos.latitude;
                        _lng = pos.longitude;
                      });
                    },
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    liteModeEnabled: false,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Toque no mapa para ajustar o pin',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.tryParse(_dateCtrl.text) ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => _dateCtrl.text =
                            DateFormat('yyyy-MM-dd').format(picked));
                      }
                    },
                    child: AbsorbPointer(
                      child: TextField(
                        controller: _dateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Data',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final parts = _timeCtrl.text.split(':');
                      final initial = parts.length == 2
                          ? TimeOfDay(
                              hour: int.tryParse(parts[0]) ?? 0,
                              minute: int.tryParse(parts[1]) ?? 0)
                          : TimeOfDay.now();
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: initial,
                      );
                      if (picked != null) {
                        setState(() => _timeCtrl.text =
                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
                      }
                    },
                    child: AbsorbPointer(
                      child: TextField(
                        controller: _timeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Horário',
                          prefixIcon: Icon(Icons.access_time),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Designar Operadores (Equipe)',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.blueGrey),
            ),
            ..._allUsers.map((u) => CheckboxListTile(
                  dense: true,
                  title: Text(u.name),
                  value: _selectedTeamIds.contains(u.id),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedTeamIds.add(u.id);
                      } else {
                        _selectedTeamIds.remove(u.id);
                      }
                    });
                  },
                )),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () async {
                  if (_serviceTypeCtrl.text.isEmpty ||
                      _addressCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Preencha os campos vitais!')));
                    return;
                  }

                  final auth = context.read<AuthProvider>();
                  final svcCtrl = context.read<ServiceProvider>();
                  final notifCtrl = context.read<NotificationProvider>();

                  final user = auth.currentUser!;
                  final managerId = auth.managerId!;

                  final serviceToInsert = {
                    "id": const Uuid().v4(),
                    "managerId": managerId,
                    "createdById": user.id,
                    "teamIds": _selectedTeamIds,
                    "status": ServiceStatus.IN_PROGRESS.name,
                    "createdAt": DateTime.now().toIso8601String(),
                    "serviceTypeSnapshot": _serviceTypeCtrl.text.trim(),
                    "departmentSnapshot": _departmentCtrl.text.trim(),
                    "dateSnapshot": _dateCtrl.text.trim(),
                    "timeSnapshot": _timeCtrl.text.trim(),
                    "locationSnapshot": {
                      "address": _addressCtrl.text.trim(),
                      if (_lat != null) "lat": _lat,
                      if (_lng != null) "lng": _lng,
                    }
                  };

                  await svcCtrl.createServiceDirectly(
                      serviceToInsert, notifCtrl, user.id);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Designar Serviço'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
