package subcmd

import (
	"fmt"
	"log/slog"

	"github.com/redhat-appstudio/rhtap-cli/pkg/config"
	"github.com/redhat-appstudio/rhtap-cli/pkg/integrations"
	"github.com/redhat-appstudio/rhtap-cli/pkg/k8s"

	"github.com/spf13/cobra"
)

// IntegrationNexus is the sub-command for the "integration nexus",
// responsible for creating and updating the Nexus integration secret.
type IntegrationNexus struct {
	cmd    *cobra.Command // cobra command
	logger *slog.Logger   // application logger
	cfg    *config.Config // installer configuration
	kube   *k8s.Kube      // kubernetes client

	nexusIntegration *integrations.NexusIntegration // nexus integration

	dockerconfigjson string // credentials to push/pull from the registry
}

var _ Interface = &IntegrationNexus{}

const nexusIntegrationLongDesc = `
Manages the Nexus integration with RHTAP, by storing the required
credentials required by the RHTAP services to interact with Nexus.

The credentials are stored in a Kubernetes Secret in the configured namespace
for RHDH.
`

// Cmd exposes the cobra instance.
func (d *IntegrationNexus) Cmd() *cobra.Command {
	return d.cmd
}

// Complete is a no-op in this case.
func (d *IntegrationNexus) Complete(args []string) error {
	return nil
}

// Validate checks if the required configuration is set.
func (d *IntegrationNexus) Validate() error {
	feature, err := d.cfg.GetFeature(config.RedHatDeveloperHub)
	if err != nil {
		return err
	}
	if !feature.Enabled {
		return fmt.Errorf("Red Hat Developer Hub feature is not enabled")
	}
	return d.nexusIntegration.Validate()
}

// Run creates or updates the Nexus integration secret.
func (d *IntegrationNexus) Run() error {
	if err := d.nexusIntegration.EnsureNamespace(d.cmd.Context()); err != nil {
		return err
	}
	return d.nexusIntegration.Create(d.cmd.Context())
}

// NewIntegrationNexus creates the sub-command for the "integration nexus"
// responsible to manage the RHTAP integrations with a Nexus image registry.
func NewIntegrationNexus(
	logger *slog.Logger,
	cfg *config.Config,
	kube *k8s.Kube,
) *IntegrationNexus {
	nexusIntegration := integrations.NewNexusIntegration(logger, cfg, kube)

	d := &IntegrationNexus{
		cmd: &cobra.Command{
			Use:          "nexus [flags]",
			Short:        "Integrates a Nexus instance into RHTAP",
			Long:         nexusIntegrationLongDesc,
			SilenceUsage: true,
		},

		logger: logger,
		cfg:    cfg,
		kube:   kube,

		nexusIntegration: nexusIntegration,
	}

	p := d.cmd.PersistentFlags()
	nexusIntegration.PersistentFlags(p)
	return d
}
