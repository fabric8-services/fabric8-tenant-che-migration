import ceylon.file {
    parsePath,
    File,
    Nil
}
import ceylon.json {
    Object
}
import ceylon.logging {
    Priority
}
import ceylon.time {
    systemTime
}

import io.fabric8.kubernetes.api.model {
    PodBuilder,
    Pod
}
import io.fabric8.openshift.client {
    DefaultOpenShiftClient
}
import io.fabric8.tenant.che.migration.workspaces {
    logSettings,
    log
}

"Run the module `io.fabric8.tenant.che.migration.namespace`."
suppressWarnings("expressionTypeNothing")
shared void run() {
    value identityId = env.identityId;
    value requestId = env.requestId;

    function logToJson(Priority p, String m, Throwable? t) {
        variable String stacktrace = "";
        if (exists t) {
            printStackTrace(t, (st) { stacktrace += st; });
        }
        return Object({
            "timestamp" -> systemTime.milliseconds(),
            "logger_name" -> "fabric8-tenant-che-migration",
            "message" -> m,
            "priority" -> p.string,
            if (! stacktrace.empty) then "stack_trace" -> stacktrace else null,
            if (exists id = identityId) then "identity_id" -> id else null,
            if (exists id = requestId) then "req_id" -> id else null
        }.coalesced).string;
    }
    logSettings.format = logToJson;

    if (! requestId exists) {
        log.warn("REQUEST_ID doesn't exit. The config map is probably missing. Let's skip this migration without failing");
        writeTerminationStatus(0);
        process.exit(0);
    }

    variable Integer exitCode;
    try {
        exitCode = doMigration();
        writeTerminationStatus(exitCode);
//        if (exists requestId) {
//            addJobLabel(requestId, "success", (exitCode == 0).string);
//        }
    } catch(Throwable e) {
        log.error("Unknown error during namespace migration", e);
    } finally {
        cleanMigrationResources();
    }
    process.exit(0);
}

void writeTerminationStatus(Integer exitCode) {
    value logFile = switch(resource = parsePath("/dev/termination-log").resource)
    case (is Nil) resource.createFile()
    case (is File) resource
    else null;
    if (exists logFile) {
        try (appender = logFile.Appender()) {
            appender.write(exitCode.string);
        }
    }
}

void addJobLabel(String requestId, String labelName, String labelValue) {
    try(oc = DefaultOpenShiftClient()) {

        value namespace = osioCheNamespace(oc);

        function containsRequestId(Pod pod) => toCeylon(pod.metadata.annotations)
            .contains("request-id" -> requestId);

        void patch(Pod pod) {
            oc.pods()
            .withName(pod.metadata.name)
            .patch(PodBuilder(pod).editMetadata().addToLabels(labelName, labelValue).endMetadata().build());
        }

        value migrationPods = oc.pods().inNamespace(namespace).withLabel("migration").list().items;

        for (pod in migrationPods) {
            if (containsRequestId(pod)) {
                patch(pod);
            }
        }

    } catch(Exception e) {
        log.warn("Exception while adding the success label to the migration job and pod", e);
    }
}
